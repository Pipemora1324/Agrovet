"""Evaluación del LSTM de alerta temprana: líneas base, robustez, umbrales e importancia de variables.

Todo se calcula sobre el dataset SINTÉTICO de generate_dataset.py. Los números sirven para conocer
el comportamiento del pipeline y sus puntos débiles; no tienen validez clínica ni validan la
hipótesis del proyecto (F1 >= 0,80).

Este módulo no carga TensorFlow: el modelo llega como una función que recibe ventanas normalizadas
y devuelve probabilidades. Así se puede probar con modelos de juguete y con mutmut.
"""

from collections.abc import Callable
from typing import Any

import numpy as np
import pandas as pd
from numpy.typing import ArrayLike
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

from preprocess import (
    FEATURES,
    HORIZON_MAX_DAYS,
    HORIZON_MIN_DAYS,
    TEMP_SCALE,
    WINDOW_DAYS,
    clean_window,
    normalize_window,
)

Predictor = Callable[[np.ndarray], np.ndarray]

# Ruido diario del generador (temperatura en °C; leche y alimento como fracción de la base).
# El ruido de la prueba de robustez se expresa en múltiplos de estas unidades.
NOISE_UNITS = (0.15, 0.05, 0.06)
NOISE_LEVELS = (0.5, 1.0, 2.0, 3.0)
MISSING_FRACTIONS = (0.10, 0.20, 0.30)
MISSING_DAYS = (1, 2, 3, 4)

# Fincas simuladas para el desplazamiento de distribución: cambios sobre DatasetParams
HIGH_PRODUCTION = {"base_milk_mean": 24.0, "base_milk_sd": 5.0, "base_feed_mean": 17.0, "base_feed_sd": 3.0}
HOT_CLIMATE = {"heat_stress_scale": 2.0}
NOISY_RECORDS = {"noise_scale": 2.0, "error_fraction": 0.06}
MILD_SHORT_DISEASE = {"subclinical_min_days": 3, "subclinical_max_days": 5, "severity_min": 0.3,
                      "severity_max": 0.9}
FARMS: dict[str, dict[str, Any]] = {
    "misma_finca_otras_vacas": {},
    "alta_produccion": HIGH_PRODUCTION,
    "clima_calido": HOT_CLIMATE,
    "registros_ruidosos": NOISY_RECORDS,
    "subclinica_corta_y_leve": MILD_SHORT_DISEASE,
    "otra_finca_combinada": {**HIGH_PRODUCTION, **HOT_CLIMATE, **NOISY_RECORDS, **MILD_SHORT_DISEASE,
                             "base_temp_mean": 38.8},
}


# --- Ventanas -------------------------------------------------------------------------------------

def raw_windows(df):
    """Las mismas ventanas, etiquetas y meta que preprocess.build_windows, pero sin limpiar ni
    normalizar, para poder degradarlas antes del preprocesamiento (como le llegarían a la app)."""
    raws, ys, rows = [], [], []
    columns = list(FEATURES)
    for cow_id, cow in df.sort_values(["cow_id", "day"]).groupby("cow_id", sort=True):
        values = cow[columns].to_numpy(dtype=np.float64)
        days = cow["day"].to_numpy()
        sick = bool(cow["sick"].iloc[0])
        onset = int(cow["onset_day"].iloc[0])
        for end in range(WINDOW_DAYS - 1, len(cow)):
            end_day = int(days[end])
            if sick and end_day >= onset:
                break
            raw = values[end - WINDOW_DAYS + 1:end + 1]
            if not clean_window(raw)[1]:
                continue
            days_to_onset = onset - end_day if sick else np.nan
            raws.append(raw)
            ys.append(int(sick and HORIZON_MIN_DAYS <= days_to_onset <= HORIZON_MAX_DAYS))
            rows.append((cow_id, end_day, days_to_onset, sick))
    meta = pd.DataFrame(rows, columns=["cow_id", "end_day", "days_to_onset", "sick"])
    return np.stack(raws), np.array(ys, dtype=np.int32), meta


def preprocess_batch(raw):
    """Limpia y normaliza cada ventana. Devuelve (X, utilizable); X vale 0 en las no utilizables."""
    X = np.zeros(raw.shape, dtype=np.float32)
    usable = np.zeros(len(raw), dtype=bool)
    for i, window in enumerate(raw):
        clean, ok = clean_window(window)
        if ok:
            X[i] = normalize_window(clean)
            usable[i] = True
    return X, usable


# --- Degradaciones de las ventanas crudas ---------------------------------------------------------

def add_noise(raw, level, rng):
    """Ruido gaussiano en múltiplos de NOISE_UNITS: aditivo en la temperatura y relativo en la leche y
    el alimento. Los faltantes siguen faltando."""
    out = np.array(raw, dtype=np.float64)
    temp_unit, milk_unit, feed_unit = NOISE_UNITS
    out[..., 0] += rng.normal(0.0, level * temp_unit, out.shape[:-1])
    out[..., 1] *= 1.0 + rng.normal(0.0, level * milk_unit, out.shape[:-1])
    out[..., 2] *= 1.0 + rng.normal(0.0, level * feed_unit, out.shape[:-1])
    return out


def drop_values(raw, fraction, rng, whole_days=False):
    """Borra al azar una fracción de los datos: celdas sueltas o, con whole_days, días completos
    (las tres variables del mismo día, como cuando no se registra ese día)."""
    out = np.array(raw, dtype=np.float64)
    if whole_days:
        out[rng.random(out.shape[:-1]) < fraction] = np.nan
    else:
        out[rng.random(out.shape) < fraction] = np.nan
    return out


def missing_days(raw, n_days, where):
    """Ventana incompleta: faltan los primeros días ('start', historia corta) o los últimos ('end',
    días recientes sin registrar)."""
    if where not in ("start", "end"):
        raise ValueError(f"where debe ser 'start' o 'end', llegó {where!r}")
    out = np.array(raw, dtype=np.float64)
    if n_days > 0:
        if where == "start":
            out[:, :n_days] = np.nan
        else:
            out[:, -n_days:] = np.nan
    return out


# --- Líneas base ----------------------------------------------------------------------------------

def temperature_score(X):
    """Línea base de umbral de temperatura: °C del último día sobre la base de los primeros 7 días."""
    return np.asarray(X)[:, -1, 0] * TEMP_SCALE


def flatten(X):
    X = np.asarray(X)
    return X.reshape(len(X), -1)


def baseline_estimators(seed=42):
    """Líneas base entrenables, con hiperparámetros fijos (sin búsqueda)."""
    return {
        "regresion_logistica": make_pipeline(StandardScaler(),
                                             LogisticRegression(class_weight="balanced", max_iter=2000)),
        "random_forest": RandomForestClassifier(n_estimators=300, min_samples_leaf=5,
                                                class_weight="balanced_subsample", n_jobs=-1,
                                                random_state=seed),
    }


def fit_baselines(X_train, y_train, seed=42):
    """Entrena las líneas base sobre las mismas ventanas que el LSTM. Devuelve
    {nombre: función ventanas -> puntaje}."""
    estimators = baseline_estimators(seed)
    logistic, forest = estimators["regresion_logistica"], estimators["random_forest"]
    logistic.fit(flatten(X_train), y_train)
    forest.fit(flatten(X_train), y_train)
    return {
        "umbral_temperatura": temperature_score,
        "regresion_logistica": lambda X: logistic.predict_proba(flatten(X))[:, 1],
        "random_forest": lambda X: forest.predict_proba(flatten(X))[:, 1],
    }


# --- Métricas -------------------------------------------------------------------------------------

def binary_metrics(labels: ArrayLike, scores: ArrayLike, threshold: float) -> dict:
    """F1, precisión, sensibilidad (recall), especificidad y AUC con un umbral (puntaje >= umbral)."""
    labels, scores = np.asarray(labels), np.asarray(scores)
    preds = scores >= threshold
    tp = int(np.sum(preds & (labels == 1)))
    fp = int(np.sum(preds & (labels == 0)))
    fn = int(np.sum(~preds & (labels == 1)))
    tn = int(np.sum(~preds & (labels == 0)))
    precision = tp / (tp + fp) if tp + fp else 0.0
    recall = tp / (tp + fn) if tp + fn else 0.0
    return {
        "f1": 2 * tp / (2 * tp + fp + fn) if tp + fp + fn else 0.0,
        "precision": precision,
        "recall": recall,
        "specificity": tn / (tn + fp) if tn + fp else 0.0,
        "auc": float(roc_auc_score(labels, scores)) if len(np.unique(labels)) == 2 else float("nan"),
        "confusion": {"tn": tn, "fp": fp, "fn": fn, "tp": tp},
    }


BOOT_METRICS = ("f1", "auc", "recall", "precision")


def grouped_bootstrap(labels, scores_by_model, thresholds, groups, reference, n_boot=2000, seed=0):
    """IC 95 % por percentiles de F1, AUC, sensibilidad y precisión, remuestreando VACAS con reemplazo.
    También la diferencia pareada de cada modelo contra `reference` en las mismas muestras. Las muestras
    con una sola clase se descartan."""
    labels, groups = np.asarray(labels), np.asarray(groups)
    unique = np.unique(groups)
    members = {g: np.flatnonzero(groups == g) for g in unique}
    rng = np.random.default_rng(seed)
    values: dict[str, dict[str, list[float]]] = {m: {k: [] for k in BOOT_METRICS} for m in scores_by_model}
    for _ in range(n_boot):
        idx = np.concatenate([members[g] for g in rng.choice(unique, size=len(unique), replace=True)])
        if len(np.unique(labels[idx])) < 2:
            continue
        for model, scores in scores_by_model.items():
            sample = binary_metrics(labels[idx], np.asarray(scores)[idx], thresholds[model])
            for key in BOOT_METRICS:
                values[model][key].append(sample[key])

    def interval(series):
        low, high = np.percentile(series, [2.5, 97.5])
        return float(low), float(high)

    result = {}
    ref = values[reference]
    for model, series in values.items():
        result[model] = {f"{key}_ci95": interval(series[key]) for key in BOOT_METRICS}
        if model != reference:
            for key in ("f1", "auc", "recall"):
                diff = np.asarray(series[key]) - np.asarray(ref[key])
                result[model][f"{key}_minus_{reference}_ci95"] = interval(diff)
    return result


def cow_level(meta, scores, threshold):
    """A nivel de vaca: fracción de vacas enfermas con alerta en alguna ventana 1 a 5 días antes del
    inicio y fracción de vacas sanas con al menos una alerta (misma definición que train_lstm)."""
    scores = np.asarray(scores)
    alerts = scores >= threshold
    sick = meta["sick"].to_numpy(dtype=bool)
    in_horizon = sick & meta["days_to_onset"].between(HORIZON_MIN_DAYS, HORIZON_MAX_DAYS).to_numpy()
    cows = meta["cow_id"].to_numpy()
    sick_cows = np.unique(cows[sick])
    healthy_cows = np.unique(cows[~sick])
    detected = np.unique(cows[in_horizon & alerts])
    healthy_alerted = np.unique(cows[~sick & alerts])
    return {
        "sick_cows": int(len(sick_cows)),
        "sick_cows_detected_rate": len(detected) / len(sick_cows) if len(sick_cows) else float("nan"),
        "healthy_cows": int(len(healthy_cows)),
        "healthy_cows_with_alert_rate": (len(healthy_alerted) / len(healthy_cows)
                                         if len(healthy_cows) else float("nan")),
    }


def degradation_row(labels, scores, usable, threshold):
    """Fila de la tabla de degradación. Las métricas se calculan sobre las ventanas que el
    preprocesamiento acepta; `recall_all_windows` cuenta como no detectadas las ventanas de riesgo que
    quedan sin evaluar (la app no da color si faltan datos)."""
    labels, scores, usable = np.asarray(labels), np.asarray(scores), np.asarray(usable, dtype=bool)
    row = binary_metrics(labels[usable], scores[usable], threshold)
    positives = int(np.sum(labels == 1))
    row["coverage"] = float(usable.mean())
    row["recall_all_windows"] = row["confusion"]["tp"] / positives if positives else float("nan")
    return row


def threshold_sweep(labels, scores, meta, thresholds):
    """Métricas por ventana y por vaca para cada umbral del rojo."""
    rows = []
    for threshold in thresholds:
        metrics = binary_metrics(labels, scores, threshold)
        metrics.pop("auc")
        rows.append({"threshold": float(threshold), **metrics, **cow_level(meta, scores, threshold)})
    return rows


def yellow_sweep(labels, scores, red_threshold, yellow_thresholds):
    """Para cada corte del amarillo: ventanas de riesgo en amarillo o rojo y ventanas sanas en amarillo
    (o en amarillo o rojo). El rojo queda fijo."""
    labels, scores = np.asarray(labels), np.asarray(scores)
    positive, negative = labels == 1, labels == 0
    rows = []
    for yellow in yellow_thresholds:
        at_least_yellow = scores >= yellow
        only_yellow = at_least_yellow & (scores < red_threshold)
        rows.append({
            "yellow_threshold": float(yellow),
            "risk_windows_yellow_or_red": float(at_least_yellow[positive].mean()),
            "healthy_windows_yellow": float(only_yellow[negative].mean()),
            "healthy_windows_yellow_or_red": float(at_least_yellow[negative].mean()),
        })
    return rows


def permutation_importance(predict: Predictor, X, labels, threshold, n_repeats=30, seed=0):
    """Importancia de cada variable: se baraja la serie completa de 14 días de esa variable entre
    ventanas (se mantiene su forma en el tiempo y se rompe su relación con la etiqueta) y se mide cuánto
    bajan el AUC y el F1. Devuelve la media, la desviación y los percentiles 2,5 y 97,5 de la caída."""
    X, labels = np.asarray(X), np.asarray(labels)
    base = binary_metrics(labels, predict(X), threshold)
    rng = np.random.default_rng(seed)
    result: dict[str, dict[str, Any]] = {}
    for j, name in enumerate(FEATURES):
        drops: dict[str, list[float]] = {"auc": [], "f1": []}
        for _ in range(n_repeats):
            shuffled = X.copy()
            shuffled[:, :, j] = X[rng.permutation(len(X)), :, j]
            sample = binary_metrics(labels, predict(shuffled), threshold)
            for key, series in drops.items():
                series.append(base[key] - sample[key])
        result[name] = {}
        for key, series in drops.items():
            low, high = np.percentile(series, [2.5, 97.5])
            result[name][f"{key}_drop_mean"] = float(np.mean(series))
            result[name][f"{key}_drop_sd"] = float(np.std(series))
            result[name][f"{key}_drop_ci95"] = (float(low), float(high))
    return result
