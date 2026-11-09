"""Validación cruzada agrupada y métricas con intervalo de confianza para la CNN de la ubre.

Con ~120 fotos un único conjunto de prueba casi no informa, así que se usa
StratifiedGroupKFold 5x5: cada foto se evalúa una vez por repetición en un modelo que no la vio,
y todas las fotos de una misma vaca caen en el mismo fold.
"""

import numpy as np
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import StratifiedGroupKFold

Z_95 = 1.959963984540054


def repeated_group_folds(labels, groups, n_splits=5, n_repeats=5, seed=42):
    """Lista de (repetición, fold, índices de entrenamiento, índices de prueba)."""
    labels, groups = np.asarray(labels), np.asarray(groups)
    folds = []
    for rep in range(n_repeats):
        splitter = StratifiedGroupKFold(n_splits=n_splits, shuffle=True, random_state=seed + rep)
        for fold, (train_idx, test_idx) in enumerate(splitter.split(np.zeros(len(labels)), labels, groups)):
            folds.append((rep, fold, train_idx, test_idx))
    return folds


def inner_validation_split(labels, groups, train_idx, seed=0, n_splits=6):
    """Separa ~1/n_splits de los grupos de entrenamiento para la parada temprana (sin fuga)."""
    labels, groups = np.asarray(labels), np.asarray(groups)
    splitter = StratifiedGroupKFold(n_splits=n_splits, shuffle=True, random_state=seed)
    fit_rel, val_rel = next(splitter.split(np.zeros(len(train_idx)), labels[train_idx], groups[train_idx]))
    return np.asarray(train_idx)[fit_rel], np.asarray(train_idx)[val_rel]


def balanced_class_weight(labels):
    labels = np.asarray(labels)
    n, counts = len(labels), np.bincount(labels, minlength=2)
    return {c: float(n / (2 * counts[c])) for c in (0, 1) if counts[c] > 0}


def wilson_interval(successes, total, z=Z_95):
    """Intervalo de Wilson para una proporción (adecuado con n pequeño)."""
    if total == 0:
        return float("nan"), float("nan")
    p = successes / total
    denom = 1 + z * z / total
    center = (p + z * z / (2 * total)) / denom
    half = z * np.sqrt(p * (1 - p) / total + z * z / (4 * total * total)) / denom
    return float(max(0.0, center - half)), float(min(1.0, center + half))


def confusion(labels, predictions):
    labels, predictions = np.asarray(labels), np.asarray(predictions)
    return {
        "tn": int(np.sum((labels == 0) & (predictions == 0))),
        "fp": int(np.sum((labels == 0) & (predictions == 1))),
        "fn": int(np.sum((labels == 1) & (predictions == 0))),
        "tp": int(np.sum((labels == 1) & (predictions == 1))),
    }


def grouped_bootstrap_auc(labels, scores, groups, n_boot=2000, seed=0):
    """AUC y su IC 95 % por percentiles, re-muestreando GRUPOS (vacas) con reemplazo."""
    labels, scores, groups = np.asarray(labels), np.asarray(scores), np.asarray(groups)
    point = float(roc_auc_score(labels, scores))
    unique = np.unique(groups)
    members = {g: np.flatnonzero(groups == g) for g in unique}
    rng = np.random.default_rng(seed)
    values = []
    for _ in range(n_boot):
        idx = np.concatenate([members[g] for g in rng.choice(unique, size=len(unique), replace=True)])
        if len(np.unique(labels[idx])) < 2:
            continue
        values.append(roc_auc_score(labels[idx], scores[idx]))
    low, high = np.percentile(values, [2.5, 97.5])
    return point, float(low), float(high)


def summarize(labels, scores, groups, threshold=0.5, n_boot=2000, seed=0):
    """Sensibilidad y especificidad (Wilson), exactitud balanceada, AUC (bootstrap por grupos) y
    matriz de confusión con el umbral dado."""
    labels, scores = np.asarray(labels), np.asarray(scores)
    cm = confusion(labels, (scores >= threshold).astype(int))
    positives, negatives = cm["tp"] + cm["fn"], cm["tn"] + cm["fp"]
    sensitivity = cm["tp"] / positives if positives else float("nan")
    specificity = cm["tn"] / negatives if negatives else float("nan")
    auc, auc_low, auc_high = grouped_bootstrap_auc(labels, scores, groups, n_boot=n_boot, seed=seed)
    return {
        "n_images": int(len(labels)),
        "n_groups": int(len(np.unique(groups))),
        "threshold": threshold,
        "sensitivity": sensitivity,
        "sensitivity_ci95": wilson_interval(cm["tp"], positives),
        "specificity": specificity,
        "specificity_ci95": wilson_interval(cm["tn"], negatives),
        "balanced_accuracy": (sensitivity + specificity) / 2,
        "auc": auc,
        "auc_ci95_group_bootstrap": (auc_low, auc_high),
        "confusion": cm,
    }
