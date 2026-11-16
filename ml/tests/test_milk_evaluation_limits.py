"""Límites y reproducibilidad de milk_evaluation: comparación con el algoritmo documentado, valores
por defecto, umbral inclusivo y entradas booleanas. Un informe de métricas tiene que dar lo mismo cada
vez que se corre con la misma semilla."""

import numpy as np
import pytest
from sklearn.metrics import roc_auc_score

from milk_evaluation import (
    brier_score,
    calibration_bins,
    expected_calibration_error,
    full_report,
    grouped_bootstrap_rates,
    paired_auc_difference,
)


def single_class_groups(seed=0, n_groups=6, per_group=3):
    """Cada grupo tiene una sola clase: muchas muestras de bootstrap salen con una sola clase."""
    rng = np.random.default_rng(seed)
    groups = np.repeat(np.arange(n_groups), per_group)
    labels = (groups % 2).astype(int)
    scores = np.clip(labels * 0.2 + rng.uniform(0, 0.8, len(labels)), 0, 1)
    preds = (scores >= 0.5).astype(int)
    return labels, preds, scores, groups


def resample(groups, rng):
    unique = np.unique(groups)
    chosen = rng.choice(unique, size=len(unique), replace=True)
    return np.concatenate([np.flatnonzero(groups == g) for g in chosen])


def reference_rates(labels, preds, groups, n_boot, seed):
    rng = np.random.default_rng(seed)
    sens, spec = [], []
    for _ in range(n_boot):
        idx = resample(groups, rng)
        y, p = labels[idx], preds[idx]
        if (y == 1).any():
            sens.append(np.mean(p[y == 1] == 1))
        if (y == 0).any():
            spec.append(np.mean(p[y == 0] == 0))
    return tuple(np.percentile(sens, [2.5, 97.5])), tuple(np.percentile(spec, [2.5, 97.5]))


def reference_delta(labels, a, b, groups, n_boot, seed):
    rng = np.random.default_rng(seed)
    deltas = []
    for _ in range(n_boot):
        idx = resample(groups, rng)
        if len(np.unique(labels[idx])) == 2:
            deltas.append(roc_auc_score(labels[idx], a[idx]) - roc_auc_score(labels[idx], b[idx]))
    return tuple(np.percentile(deltas, [2.5, 97.5]))


def test_rates_follow_the_documented_algorithm_with_single_class_samples():
    labels, preds, _, groups = single_class_groups()
    rates = grouped_bootstrap_rates(labels, preds, groups, n_boot=300, seed=7)
    sens, spec = reference_rates(labels, preds, groups, 300, 7)
    assert rates["sensitivity"] == pytest.approx(sens)
    assert rates["specificity"] == pytest.approx(spec)


def test_rates_percentiles_with_many_mixed_groups():
    # Muchos grupos con aciertos y errores mezclados: las tasas varían de a poco y se nota el percentil
    rng = np.random.default_rng(12)
    groups = np.repeat(np.arange(40), 5)
    labels = rng.integers(0, 2, len(groups))
    preds = np.where(rng.uniform(size=len(groups)) < 0.8, labels, 1 - labels)
    rates = grouped_bootstrap_rates(labels, preds, groups, n_boot=400, seed=2)
    sens, spec = reference_rates(labels, preds, groups, 400, 2)
    assert rates["sensitivity"] == pytest.approx(sens, abs=1e-12)
    assert rates["specificity"] == pytest.approx(spec, abs=1e-12)
    assert sens[0] < sens[1]
    assert spec[0] < spec[1]


def test_paired_difference_follows_the_documented_algorithm():
    labels, _, scores, groups = single_class_groups(seed=1, n_groups=8)
    other = np.clip(scores + np.random.default_rng(2).normal(0, 0.3, len(scores)), 0, 1)
    result = paired_auc_difference(labels, scores, other, groups, n_boot=300, seed=4)
    low, high = reference_delta(labels, scores, other, groups, 300, 4)
    assert (result["low"], result["high"]) == pytest.approx((low, high))
    assert low < high


def test_defaults_and_seeds_are_reproducible():
    labels, preds, scores, groups = single_class_groups(seed=3, n_groups=10)
    other = scores[::-1].copy()

    assert grouped_bootstrap_rates(labels, preds, groups) == grouped_bootstrap_rates(
        labels, preds, groups, n_boot=2000, seed=0
    )
    default = paired_auc_difference(labels, scores, other, groups)
    assert default == paired_auc_difference(labels, scores, other, groups, n_boot=2000, seed=0)
    assert default != paired_auc_difference(labels, scores, other, groups, n_boot=2000, seed=1)
    first = paired_auc_difference(labels, scores, other, groups, n_boot=200, seed=9)
    second = paired_auc_difference(labels, scores, other, groups, n_boot=200, seed=9)
    assert first == second

    report = full_report(labels, scores, groups)
    explicit = full_report(labels, scores, groups, threshold=0.5, n_boot=2000, seed=0)
    assert report == explicit


def test_full_report_uses_the_given_threshold_seed_and_bootstrap():
    labels, _, scores, groups = single_class_groups(seed=5, n_groups=10)
    report = full_report(labels, scores, groups, threshold=0.6, n_boot=150, seed=11)
    preds = (scores >= 0.6).astype(int)
    rates = grouped_bootstrap_rates(labels, preds, groups, n_boot=150, seed=11)

    assert report["threshold"] == 0.6
    assert report["sensitivity"] == pytest.approx(np.mean(preds[labels == 1] == 1))
    assert report["sensitivity_ci95_group_bootstrap"] == rates["sensitivity"]
    assert report["specificity_ci95_group_bootstrap"] == rates["specificity"]
    repeated = full_report(labels, scores, groups, threshold=0.6, n_boot=150, seed=11)
    assert report == repeated
    # El AUC y su intervalo salen de summarize con el mismo bootstrap y la misma semilla
    from cnn_evaluation import summarize

    base = summarize(labels, scores, groups, threshold=0.6, n_boot=150, seed=11)
    assert report["auc_ci95_group_bootstrap"] == base["auc_ci95_group_bootstrap"]


def test_full_report_threshold_is_inclusive():
    labels = np.array([0, 0, 1, 1])
    scores = np.array([0.2, 0.5, 0.5, 0.9])
    report = full_report(labels, scores, np.arange(4), n_boot=20)
    # Con 0,5 exacto el pozo cuenta como anormal
    assert report["confusion"] == {"tn": 1, "fp": 1, "fn": 0, "tp": 2}
    low, high = report["specificity_ci95_group_bootstrap"]
    assert low <= 0.5 <= high


def test_boolean_inputs_are_accepted():
    labels = np.array([False, False, True, True])
    probs = np.array([False, True, True, True])
    assert brier_score(labels, probs) == pytest.approx(0.25)
    # Intervalo de 0: 1 pozo, sin error. Intervalo de 1: 3 pozos, 2 anormales -> 3/4 * |1 - 2/3|
    assert expected_calibration_error(labels, probs) == pytest.approx(3 / 4 * (1 - 2 / 3))
    bins = calibration_bins(labels, probs)
    assert [b["count"] for b in bins] == [1, 3]
    assert bins[1]["fraction_abnormal"] == pytest.approx(2 / 3)


def test_default_is_ten_bins():
    probs = np.linspace(0.0, 1.0, 101)
    labels = (probs > 0.5).astype(int)
    assert len(calibration_bins(labels, probs)) == 10
    assert len(calibration_bins(labels, probs, n_bins=5)) == 5
    assert expected_calibration_error(labels, probs) == expected_calibration_error(labels, probs, n_bins=10)
    assert expected_calibration_error(labels, probs) != expected_calibration_error(labels, probs, n_bins=3)
