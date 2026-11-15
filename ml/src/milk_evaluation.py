"""Métricas del clasificador de leche que no están en cnn_evaluation: calibración, confusión por
grado, intervalos por bootstrap agrupado de sensibilidad y especificidad, y la diferencia pareada de
AUC entre dos modelos evaluados sobre los mismos pozos."""

from __future__ import annotations

import numpy as np
from numpy.typing import ArrayLike
from sklearn.metrics import roc_auc_score

from cnn_evaluation import summarize


def calibration_bins(labels: ArrayLike, probs: ArrayLike, n_bins: int = 10) -> list[dict]:
    """Curva de confiabilidad en n_bins intervalos iguales de [0, 1]: cuántos pozos caen en cada uno,
    su probabilidad media y la fracción que de verdad es anormal. Los intervalos vacíos se omiten."""
    labels_arr, probs_arr = np.asarray(labels, dtype=float), np.asarray(probs, dtype=float)
    # El último intervalo incluye el 1.0
    index = np.minimum((probs_arr * n_bins).astype(int), n_bins - 1)
    bins = []
    for b in range(n_bins):
        mask = index == b
        if mask.any():
            bins.append(
                {
                    "low": b / n_bins,
                    "high": (b + 1) / n_bins,
                    "count": int(mask.sum()),
                    "mean_probability": float(probs_arr[mask].mean()),
                    "fraction_abnormal": float(labels_arr[mask].mean()),
                }
            )
    return bins


def expected_calibration_error(labels: ArrayLike, probs: ArrayLike, n_bins: int = 10) -> float:
    """ECE: diferencia media (ponderada por cantidad) entre la probabilidad y la frecuencia real."""
    total = len(np.asarray(labels))
    return float(
        sum(
            b["count"] / total * abs(b["mean_probability"] - b["fraction_abnormal"])
            for b in calibration_bins(labels, probs, n_bins)
        )
    )


def brier_score(labels: ArrayLike, probs: ArrayLike) -> float:
    labels_arr, probs_arr = np.asarray(labels, dtype=float), np.asarray(probs, dtype=float)
    return float(np.mean((probs_arr - labels_arr) ** 2))


def grade_confusion(grades: ArrayLike, predictions: ArrayLike) -> dict[str, dict[str, int | float]]:
    """Por cada grado original (Normal, sangre, grumos, aguada): cuántos pozos se predijeron normales
    y cuántos anormales, y la fracción marcada como anormal."""
    grades_arr, preds_arr = np.asarray(grades), np.asarray(predictions)
    table: dict[str, dict[str, int | float]] = {}
    for grade in sorted(set(grades_arr.tolist())):
        mask = grades_arr == grade
        abnormal = int((preds_arr[mask] == 1).sum())
        table[grade] = {
            "n": int(mask.sum()),
            "predicted_normal": int(mask.sum()) - abnormal,
            "predicted_abnormal": abnormal,
            "fraction_abnormal": abnormal / int(mask.sum()),
        }
    return table


def _resample(groups: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    unique = np.unique(groups)
    members = {g: np.flatnonzero(groups == g) for g in unique}
    return np.concatenate([members[g] for g in rng.choice(unique, size=len(unique), replace=True)])


def grouped_bootstrap_rates(
    labels: ArrayLike, predictions: ArrayLike, groups: ArrayLike, n_boot: int = 2000, seed: int = 0
) -> dict[str, tuple[float, float]]:
    """IC 95 % de sensibilidad y especificidad re-muestreando grupos completos. A diferencia de
    Wilson, no supone pozos independientes (los de una misma foto o video se parecen)."""
    labels_arr, preds_arr, groups_arr = np.asarray(labels), np.asarray(predictions), np.asarray(groups)
    rng = np.random.default_rng(seed)
    sens, spec = [], []
    for _ in range(n_boot):
        idx = _resample(groups_arr, rng)
        y, p = labels_arr[idx], preds_arr[idx]
        if (y == 1).any():
            sens.append(float(np.mean(p[y == 1] == 1)))
        if (y == 0).any():
            spec.append(float(np.mean(p[y == 0] == 0)))

    def interval(values: list[float]) -> tuple[float, float]:
        low, high = np.percentile(values, [2.5, 97.5])
        return float(low), float(high)

    return {"sensitivity": interval(sens), "specificity": interval(spec)}


def paired_auc_difference(
    labels: ArrayLike,
    scores_a: ArrayLike,
    scores_b: ArrayLike,
    groups: ArrayLike,
    n_boot: int = 2000,
    seed: int = 0,
) -> dict[str, float]:
    """AUC(a) - AUC(b) sobre los mismos pozos, con IC 95 % por bootstrap de grupos pareado (la misma
    muestra para los dos modelos). Si el intervalo contiene 0, no hay diferencia demostrable."""
    labels_arr = np.asarray(labels)
    a_arr, b_arr, groups_arr = np.asarray(scores_a), np.asarray(scores_b), np.asarray(groups)
    point = float(roc_auc_score(labels_arr, a_arr) - roc_auc_score(labels_arr, b_arr))
    rng = np.random.default_rng(seed)
    deltas = []
    for _ in range(n_boot):
        idx = _resample(groups_arr, rng)
        if len(np.unique(labels_arr[idx])) < 2:
            continue
        deltas.append(roc_auc_score(labels_arr[idx], a_arr[idx]) - roc_auc_score(labels_arr[idx], b_arr[idx]))
    low, high = np.percentile(deltas, [2.5, 97.5])
    return {"difference": point, "low": float(low), "high": float(high)}


def full_report(
    labels: ArrayLike,
    probs: ArrayLike,
    groups: ArrayLike,
    threshold: float = 0.5,
    n_boot: int = 2000,
    seed: int = 0,
) -> dict:
    """summarize (Wilson y AUC por bootstrap) más IC por bootstrap de las tasas, ECE y Brier."""
    report = summarize(labels, probs, groups, threshold=threshold, n_boot=n_boot, seed=seed)
    predictions = (np.asarray(probs) >= threshold).astype(int)
    rates = grouped_bootstrap_rates(labels, predictions, groups, n_boot=n_boot, seed=seed)
    report["sensitivity_ci95_group_bootstrap"] = rates["sensitivity"]
    report["specificity_ci95_group_bootstrap"] = rates["specificity"]
    report["ece"] = expected_calibration_error(labels, probs)
    report["brier"] = brier_score(labels, probs)
    return report
