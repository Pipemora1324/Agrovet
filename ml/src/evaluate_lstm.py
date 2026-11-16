"""Evalúa el LSTM DESPLEGADO sobre el dataset SINTÉTICO, sin reentrenarlo ni cambiarlo.

Usa models/mastitis_lstm.tflite y el umbral de models/model_config.json: los mismos archivos que lleva
la app. Con la misma partición por vaca que train_lstm.py calcula:

1. Líneas base (umbral de temperatura, regresión logística y random forest) con IC 95 % por bootstrap
   de vacas y diferencias pareadas contra el LSTM.
2. Robustez: ruido gaussiano, datos faltantes, ventanas incompletas y fincas simuladas distintas.
3. Calibración (curva, ECE y Brier) y sensibilidad a los umbrales del semáforo (0,427 y 0,854).
4. Importancia de variables por permutación.

Salidas: reports/lstm_evaluation.json, reports/lstm_calibracion.png y reports/lstm_umbrales.png.

Todo sale de datos SINTÉTICOS: no tiene validez clínica ni valida la hipótesis F1 >= 0,80.
"""

import argparse
import hashlib
import json
import math
from collections.abc import Callable
from functools import partial
from pathlib import Path

import matplotlib
import numpy as np

from export_tflite import make_interpreter, run_tflite
from generate_dataset import DatasetParams, generate
from lstm_evaluation import (
    FARMS,
    MISSING_DAYS,
    MISSING_FRACTIONS,
    NOISE_LEVELS,
    NOISE_UNITS,
    add_noise,
    binary_metrics,
    cow_level,
    degradation_row,
    drop_values,
    fit_baselines,
    grouped_bootstrap,
    missing_days,
    permutation_importance,
    preprocess_batch,
    raw_windows,
    threshold_sweep,
    yellow_sweep,
)
from milk_evaluation import brier_score, calibration_bins, expected_calibration_error
from train_lstm import best_f1_threshold, split_cows

matplotlib.use("Agg")
import matplotlib.pyplot as plt

ML_DIR = Path(__file__).resolve().parents[1]
TFLITE_PATH = ML_DIR / "models" / "mastitis_lstm.tflite"
CONFIG_PATH = ML_DIR / "models" / "model_config.json"
REPORTS_DIR = ML_DIR / "reports"
REPORT_NAME = "lstm_evaluation.json"
CALIBRATION_FIGURE = "lstm_calibracion.png"
THRESHOLD_FIGURE = "lstm_umbrales.png"
SYNTHETIC_NOTE = ("Datos SINTÉTICOS (generate_dataset.py). Sirven para conocer el comportamiento del "
                  "pipeline; NO tienen validez clínica ni validan la hipótesis del proyecto (F1 >= 0,80).")
CAPTION = "Datos sintéticos: sin validez clínica"
LSTM = "lstm"
RED_TABLE = (0.75, 0.80, 0.83, 0.854394, 0.88, 0.90, 0.93)
YELLOW_TABLE = (0.30, 0.35, 0.40, 0.427197, 0.45, 0.50, 0.60)

# Colores del semáforo y de las series (paleta categórica por defecto, en orden fijo)
INK, MUTED, GRID = "#0b0b0b", "#52514e", "#e4e3df"
SERIES = ("#2a78d6", "#eb6834", "#1baf7a")


def rounded(value, digits=6):
    """Redondea floats anidados para el JSON; NaN pasa a None."""
    if isinstance(value, dict):
        return {k: rounded(v, digits) for k, v in value.items()}
    if isinstance(value, list | tuple):
        return [rounded(v, digits) for v in value]
    if isinstance(value, float | np.floating):
        return None if math.isnan(value) else round(float(value), digits)
    if isinstance(value, np.integer):
        return int(value)
    return value


def load_deployed(model_path, config_path):
    model_bytes = Path(model_path).read_bytes()
    config = json.loads(Path(config_path).read_text(encoding="utf-8"))
    digest = hashlib.sha256(model_bytes).hexdigest()
    interpreter = make_interpreter(model_bytes)

    def predict(X):
        return run_tflite(interpreter, np.asarray(X, dtype=np.float32)).astype(np.float64)

    info = {
        "file": "models/mastitis_lstm.tflite",
        "sha256": digest,
        "sha256_matches_config": digest == config["tflite_sha256"],
        "threshold_red": config["traffic_light"]["red"]["min"],
        "threshold_yellow": config["traffic_light"]["yellow"]["min"],
    }
    return predict, info


def split_windows(df, seed):
    """Ventanas crudas y normalizadas con la partición por vaca de train_lstm."""
    raw, labels, meta = raw_windows(df)
    X, usable = preprocess_batch(raw)
    if not usable.all():
        raise RuntimeError("raw_windows devolvió ventanas que el preprocesamiento rechaza")
    parts = {}
    for name, ids in zip(("train", "val", "test"), split_cows(df, seed)):
        mask = meta["cow_id"].isin(ids).to_numpy()
        parts[name] = {"raw": raw[mask], "X": X[mask], "y": labels[mask],
                       "meta": meta[mask].reset_index(drop=True)}
    return parts


def compare_models(scores, thresholds, labels, meta, n_boot, seed):
    cis = grouped_bootstrap(labels, scores, thresholds, meta["cow_id"].to_numpy(), LSTM, n_boot, seed)
    return {
        model: {"threshold": thresholds[model], **binary_metrics(labels, model_scores, thresholds[model]),
                **cis[model], "cow_level": cow_level(meta, model_scores, thresholds[model])}
        for model, model_scores in scores.items()
    }


Degrade = Callable[[np.ndarray, np.random.Generator], np.ndarray]


def _noise(raw, rng, level):
    return add_noise(raw, level, rng)


def _drop(raw, rng, fraction, days):
    return drop_values(raw, fraction, rng, whole_days=days)


def _cut(raw, rng, n_days, where):
    return missing_days(raw, n_days, where)


ROBUSTNESS_METRICS = ("coverage", "f1", "precision", "recall", "recall_all_windows", "specificity", "auc")


def degradation_scenarios():
    """(tipo, nivel, función de degradación, si es al azar) de cada fila de la tabla."""
    scenarios: list[tuple[str, float, Degrade | None, bool]] = [("sin_degradar", 0, None, False)]
    for level in NOISE_LEVELS:
        scenarios.append(("ruido_gaussiano", level, partial(_noise, level=level), True))
    for fraction in MISSING_FRACTIONS:
        scenarios.append(("faltantes_celdas", fraction, partial(_drop, fraction=fraction, days=False), True))
    for fraction in MISSING_FRACTIONS:
        scenarios.append(("faltantes_dias_completos", fraction,
                          partial(_drop, fraction=fraction, days=True), True))
    for where, kind in (("start", "faltan_primeros_dias"), ("end", "faltan_ultimos_dias")):
        for days in MISSING_DAYS:
            scenarios.append((kind, days, partial(_cut, n_days=days, where=where), False))
    return scenarios


def evaluate_degraded(predict, raw, labels, threshold, degrade, rng):
    """Degrada, preprocesa como la app y evalúa solo las ventanas que el preprocesamiento acepta."""
    degraded = raw if degrade is None else degrade(raw, rng)
    X, usable = preprocess_batch(degraded)
    scores = np.zeros(len(X))
    if usable.any():
        scores[usable] = predict(X[usable])
    return degradation_row(labels, scores, usable, threshold)


def robustness(predict, raw, labels, threshold, repeats, seed):
    """Tabla de degradación del LSTM. Las degradaciones al azar se repiten `repeats` veces y se
    reporta la media y el rango de cada métrica."""
    rows = []
    for index, (kind, level, degrade, random) in enumerate(degradation_scenarios()):
        draws = [evaluate_degraded(predict, raw, labels, threshold, degrade,
                                   np.random.default_rng(seed + 100 * index + rep))
                 for rep in range(repeats if random else 1)]
        row = {"degradation": kind, "level": level, "draws": len(draws)}
        for key in ROBUSTNESS_METRICS:
            values = np.array([d[key] for d in draws], dtype=float)
            row[key] = float(np.mean(values))
            row[f"{key}_range"] = (float(np.min(values)), float(np.max(values)))
        rows.append(row)
    return rows


def farm_shift(predict, baselines, thresholds, farm_cows, n_boot, seed):
    """Cada finca simulada es un dataset nuevo (otras vacas, otra semilla) que ningún modelo vio."""
    farms = {}
    for index, (name, overrides) in enumerate(FARMS.items()):
        params = DatasetParams(n_cows=farm_cows, seed=seed + 1000 + index, **overrides)
        raw, labels, meta = raw_windows(generate(params))
        X, _ = preprocess_batch(raw)
        scores = {LSTM: predict(X), **{m: fn(X) for m, fn in baselines.items()}}
        farms[name] = {
            "changes": overrides,
            "windows": int(len(labels)),
            "positive_windows": int(labels.sum()),
            "prevalence": float(labels.mean()),
            "models": compare_models(scores, thresholds, labels, meta, n_boot, seed),
        }
    return farms


def save_calibration_plot(bins, ece, thresholds, path):
    fig, (ax, hist) = plt.subplots(2, 1, figsize=(5.5, 6.2), height_ratios=(3, 1.2), sharex=True)
    centers = [(b["low"] + b["high"]) / 2 for b in bins]
    observed = [b["fraction_abnormal"] for b in bins]
    predicted = [b["mean_probability"] for b in bins]
    ax.plot([0, 1], [0, 1], color=MUTED, linewidth=1, linestyle="--", label="calibración perfecta")
    ax.plot(predicted, observed, color=SERIES[0], linewidth=2, marker="o", markersize=5,
            label=f"LSTM desplegado (ECE {ece:.3f})")
    for value, label in thresholds:
        for axis in (ax, hist):
            axis.axvline(value, color=MUTED, linewidth=1, linestyle=":")
        ax.text(value, 0.98, f" {label} {value:.3f}", color=MUTED, fontsize=8, va="top")
    ax.set_ylabel("fracción real de ventanas de riesgo")
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.grid(color=GRID, linewidth=0.6)
    ax.legend(loc="center left", fontsize=8, frameon=False)
    ax.set_title(f"Curva de calibración (test, 10 intervalos)\n{CAPTION}", fontsize=9, color=INK)
    hist.bar(centers, [b["count"] for b in bins], width=0.096, color=SERIES[0])
    hist.set_yscale("log")
    hist.set_xlabel("probabilidad predicha")
    hist.set_ylabel("ventanas")
    hist.grid(color=GRID, linewidth=0.6, axis="y")
    fig.tight_layout()
    fig.savefig(path, dpi=120)
    plt.close(fig)


def save_threshold_plot(sweep, thresholds, path):
    fig, ax = plt.subplots(figsize=(6.2, 4.2))
    xs = [row["threshold"] for row in sweep]
    for color, key, label in zip(SERIES, ("f1", "precision", "recall"), ("F1", "precisión", "sensibilidad")):
        ys = [row[key] for row in sweep]
        ax.plot(xs, ys, color=color, linewidth=2, label=label)
        ax.text(xs[-1] + 0.005, ys[-1], label, color=INK, fontsize=8, va="center")
    for value, label in thresholds:
        ax.axvline(value, color=MUTED, linewidth=1, linestyle=":")
        ax.text(value, 1.0, f" {label} {value:.3f}", color=MUTED, fontsize=8, va="top")
    ax.set_xlabel("umbral del rojo")
    ax.set_ylabel("valor en test (por ventana)")
    ax.set_xlim(xs[0], xs[-1] + 0.08)
    ax.set_ylim(0, 1.02)
    ax.grid(color=GRID, linewidth=0.6)
    ax.legend(loc="lower left", fontsize=8, frameon=False)
    ax.set_title(f"Sensibilidad al umbral del LSTM desplegado\n{CAPTION}", fontsize=9, color=INK)
    fig.tight_layout()
    fig.savefig(path, dpi=120)
    plt.close(fig)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Evalúa el LSTM desplegado (datos sintéticos).")
    parser.add_argument("--model", type=Path, default=TFLITE_PATH)
    parser.add_argument("--config", type=Path, default=CONFIG_PATH)
    parser.add_argument("--n-cows", type=int, default=DatasetParams.n_cows,
                        help="Vacas del dataset; con el valor por defecto es el mismo de train_lstm.py")
    parser.add_argument("--farm-cows", type=int, default=600)
    parser.add_argument("--n-boot", type=int, default=2000)
    parser.add_argument("--repeats", type=int, default=5)
    parser.add_argument("--perm-repeats", type=int, default=30)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args(argv)

    predict, model_info = load_deployed(args.model, args.config)
    red, yellow = model_info["threshold_red"], model_info["threshold_yellow"]

    df = generate(DatasetParams(n_cows=args.n_cows))
    parts = split_windows(df, args.seed)
    train, val, test = parts["train"], parts["val"], parts["test"]
    print(f"Ventanas: train {len(train['y'])}, val {len(val['y'])}, test {len(test['y'])}", flush=True)

    # 1. Líneas base: mismas ventanas de entrenamiento y misma regla de umbral (máximo F1 en validación)
    baselines = fit_baselines(train["X"], train["y"], seed=args.seed)
    thresholds = {LSTM: red}
    thresholds.update({m: best_f1_threshold(val["y"], fn(val["X"])) for m, fn in baselines.items()})
    test_scores = {LSTM: predict(test["X"]), **{m: fn(test["X"]) for m, fn in baselines.items()}}
    lstm_test = test_scores[LSTM]
    comparison = compare_models(test_scores, thresholds, test["y"], test["meta"], args.n_boot, args.seed)
    print("Líneas base listas", flush=True)

    # 2. Robustez y fincas simuladas
    degradation = robustness(predict, test["raw"], test["y"], red, args.repeats, args.seed)
    print("Degradación lista", flush=True)
    farms = farm_shift(predict, baselines, thresholds, args.farm_cows, args.n_boot, args.seed)
    print("Fincas simuladas listas", flush=True)

    # 3. Calibración y umbrales
    bins = calibration_bins(test["y"], lstm_test)
    ece = expected_calibration_error(test["y"], lstm_test)
    grid = np.round(np.arange(0.30, 0.9801, 0.01), 2)
    sweep = threshold_sweep(test["y"], lstm_test, test["meta"], grid)
    best = max(sweep, key=lambda row: row["f1"])
    marks = [(yellow, "amarillo"), (red, "rojo")]
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    save_calibration_plot(bins, ece, marks, REPORTS_DIR / CALIBRATION_FIGURE)
    save_threshold_plot(sweep, marks, REPORTS_DIR / THRESHOLD_FIGURE)

    # 4. Importancia por permutación
    importance = permutation_importance(predict, test["X"], test["y"], red, n_repeats=args.perm_repeats,
                                        seed=args.seed)

    report = {
        "note": SYNTHETIC_NOTE,
        "model": model_info,
        "data": {
            "params": "DatasetParams() por defecto (600 vacas, 60 días, semilla 42)"
            if args.n_cows == DatasetParams.n_cows else f"DatasetParams(n_cows={args.n_cows})",
            "split": "70/15/15 por vaca, estratificada (train_lstm.split_cows)",
            **{name: {"cows": int(p["meta"]["cow_id"].nunique()), "windows": int(len(p["y"])),
                      "positive_windows": int(p["y"].sum())} for name, p in parts.items()},
        },
        "baselines": {
            "definitions": {
                "umbral_temperatura": "°C del último día sobre la media de los primeros 7 días de la ventana",
                "regresion_logistica": "42 valores normalizados (14 días x 3), estandarizados, pesos "
                                       "balanceados",
                "random_forest": "42 valores normalizados, 300 árboles, hoja mínima 5, pesos balanceados",
                "threshold_rule": "Máximo F1 en validación, la misma regla que eligió el umbral del LSTM",
                "ci": f"Bootstrap de vacas del test, {args.n_boot} remuestreos, percentiles 2,5 y 97,5",
            },
            "test": comparison,
        },
        "robustness": {
            "noise_units": {"temperature_c": NOISE_UNITS[0], "milk_relative": NOISE_UNITS[1],
                            "feed_relative": NOISE_UNITS[2]},
            "notes": "Degradaciones sobre las ventanas crudas del test, antes del preprocesamiento de la "
                     "app. Ruido: nivel x unidades (ruido diario del generador). Las métricas son sobre "
                     "las ventanas que el preprocesamiento acepta (>= 10 días válidos por variable); "
                     "recall_all_windows cuenta como no detectadas las de riesgo que quedan sin evaluar.",
            "table": degradation,
        },
        "farm_shift": farms,
        "calibration": {
            "ece_10_bins": ece,
            "brier": brier_score(test["y"], lstm_test),
            "mean_probability": float(np.mean(lstm_test)),
            "positive_rate": float(np.mean(test["y"])),
            "bins": bins,
        },
        "thresholds": {
            "red": threshold_sweep(test["y"], lstm_test, test["meta"], RED_TABLE),
            "yellow": yellow_sweep(test["y"], lstm_test, red, YELLOW_TABLE),
            "best_f1_on_test": {"threshold": best["threshold"], "f1": best["f1"],
                                "note": "Solo de referencia: elegir el umbral en test es optimista."},
        },
        "permutation_importance": {
            "method": f"Se baraja entre ventanas la serie de 14 días de una variable; {args.perm_repeats} "
                      "repeticiones; caída del AUC y del F1 (umbral del rojo) en test",
            "features": importance,
        },
        "settings": {"n_boot": args.n_boot, "repeats": args.repeats, "perm_repeats": args.perm_repeats,
                     "farm_cows": args.farm_cows, "seed": args.seed},
    }
    with open(REPORTS_DIR / REPORT_NAME, "w", encoding="utf-8") as fh:
        json.dump(rounded(report), fh, ensure_ascii=False, indent=2)
    print(json.dumps(rounded({"test": {m: {k: v[k] for k in ("f1", "auc", "recall", "f1_ci95")}
                                       for m, v in comparison.items()}}), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
