"""Casos límite y reproducibilidad de las métricas de la CNN. Un informe de métricas tiene que dar lo
mismo cada vez que se corre con la misma semilla, y los valores por defecto son parte del diseño
(validación 5x5, bootstrap de 2000 muestras)."""

import math

import numpy as np
import pytest

from cnn_evaluation import (
    balanced_class_weight,
    grouped_bootstrap_auc,
    inner_validation_split,
    repeated_group_folds,
    summarize,
    wilson_interval,
)


def dataset(n_groups=20, per_group=3, seed=0):
    rng = np.random.default_rng(seed)
    groups = np.repeat(np.arange(n_groups), per_group)
    labels = (groups % 2).astype(int)
    scores = np.clip(labels * 0.3 + rng.uniform(0, 0.7, len(labels)), 0, 1)
    return labels, scores, groups


def as_lists(folds):
    return [(rep, fold, train.tolist(), test.tolist()) for rep, fold, train, test in folds]


def test_default_cross_validation_is_five_by_five_and_reproducible():
    labels, _, groups = dataset()
    folds = repeated_group_folds(labels, groups)

    assert len(folds) == 25
    assert {rep for rep, *_ in folds} == set(range(5))
    assert as_lists(folds) == as_lists(repeated_group_folds(labels, groups, n_splits=5, n_repeats=5, seed=42))
    assert as_lists(folds) == as_lists(repeated_group_folds(labels, groups))


def test_each_repetition_uses_the_next_seed():
    labels, _, groups = dataset()
    second = [f for f in repeated_group_folds(labels, groups, n_repeats=2, seed=42) if f[0] == 1]
    alone = repeated_group_folds(labels, groups, n_repeats=1, seed=43)
    assert [f[1:] for f in as_lists(second)] == [f[1:] for f in as_lists(alone)]


def test_number_of_splits_is_respected():
    labels, _, groups = dataset()
    assert len(repeated_group_folds(labels, groups, n_splits=3, n_repeats=2)) == 6


def test_inner_validation_defaults_are_reproducible():
    labels, _, groups = dataset(n_groups=30)
    train_idx = np.arange(len(labels))
    fit, val = inner_validation_split(labels, groups, train_idx)

    expected_fit, expected_val = inner_validation_split(labels, groups, train_idx, seed=0, n_splits=6)
    assert fit.tolist() == expected_fit.tolist() and val.tolist() == expected_val.tolist()
    # Seis particiones: la validación se queda con 5 de los 30 grupos
    assert len(np.unique(groups[val])) == 5


def test_class_weights_with_a_single_class():
    assert balanced_class_weight([0, 0, 0]) == {0: 0.5}
    assert balanced_class_weight([1, 1]) == {1: 0.5}


def test_wilson_interval_edges():
    assert all(math.isnan(v) for v in wilson_interval(0, 0))
    low, high = wilson_interval(1, 1)
    assert 0.0 < low < 1.0 and high == pytest.approx(1.0)
    assert wilson_interval(0, 5)[0] == pytest.approx(0.0, abs=1e-12)


def test_bootstrap_defaults_and_seed_are_reproducible():
    labels, scores, groups = dataset()
    default = grouped_bootstrap_auc(labels, scores, groups)
    assert default == grouped_bootstrap_auc(labels, scores, groups, n_boot=2000, seed=0)
    assert default != grouped_bootstrap_auc(labels, scores, groups, n_boot=2000, seed=1)


def reference_bootstrap(labels, scores, groups, n_boot, seed):
    """Algoritmo documentado: re-muestrear vacas completas con reemplazo, descartar muestras de una
    sola clase y tomar los percentiles 2,5 y 97,5."""
    from sklearn.metrics import roc_auc_score

    unique = np.unique(groups)
    rng = np.random.default_rng(seed)
    values = []
    for _ in range(n_boot):
        chosen = rng.choice(unique, size=len(unique), replace=True)
        idx = np.concatenate([np.flatnonzero(groups == g) for g in chosen])
        if len(np.unique(labels[idx])) == 2:
            values.append(roc_auc_score(labels[idx], scores[idx]))
    return np.percentile(values, [2.5, 97.5])


def test_bootstrap_resamples_whole_groups_and_skips_single_class_samples():
    # Cada vaca tiene una sola clase: varias muestras salen con una clase y se descartan
    labels, scores, groups = dataset(n_groups=6, per_group=2, seed=3)
    point, low, high = grouped_bootstrap_auc(labels, scores, groups, n_boot=300, seed=5)

    assert (low, high) == pytest.approx(tuple(reference_bootstrap(labels, scores, groups, 300, 5)))
    assert low < point < high or low < high


def test_bootstrap_percentiles_with_overlapping_scores():
    # Puntajes muy mezclados: el extremo superior del intervalo queda lejos de 1 y se nota el percentil
    rng = np.random.default_rng(11)
    groups = np.repeat(np.arange(15), 4)
    labels = (groups % 2).astype(int)
    scores = labels * 0.15 + rng.uniform(0, 0.85, len(labels))

    _, low, high = grouped_bootstrap_auc(labels, scores, groups, n_boot=400, seed=2)

    assert high < 0.99
    assert (low, high) == pytest.approx(tuple(reference_bootstrap(labels, scores, groups, 400, 2)))


def test_summarize_bootstrap_defaults():
    labels, scores, groups = dataset(n_groups=8, per_group=2)
    default = summarize(labels, scores, groups)
    explicit = summarize(labels, scores, groups, threshold=0.5, n_boot=2000, seed=0)
    assert default["auc_ci95_group_bootstrap"] == explicit["auc_ci95_group_bootstrap"]


def test_summarize_threshold_is_inclusive_and_defaults_to_half():
    labels = np.array([0, 0, 1, 1])
    scores = np.array([0.2, 0.5, 0.5, 0.9])
    result = summarize(labels, scores, np.arange(4), n_boot=20)
    # Con 0,5 exacto la foto cuenta como mastitis
    assert result["threshold"] == 0.5
    assert result["confusion"] == {"tn": 1, "fp": 1, "fn": 0, "tp": 2}


def test_summarize_reports_every_field_with_the_given_bootstrap():
    labels, scores, groups = dataset()
    result = summarize(labels, scores, groups, threshold=0.6, n_boot=150, seed=7)

    assert set(result) == {"n_images", "n_groups", "threshold", "sensitivity", "sensitivity_ci95",
                           "specificity", "specificity_ci95", "balanced_accuracy", "auc",
                           "auc_ci95_group_bootstrap", "confusion"}
    assert result["n_images"] == 60
    assert result["n_groups"] == 20
    assert result["threshold"] == 0.6
    cm = result["confusion"]
    assert result["specificity_ci95"] == wilson_interval(cm["tn"], cm["tn"] + cm["fp"])
    assert result["sensitivity"] != result["specificity"]
    assert result["balanced_accuracy"] == pytest.approx((result["sensitivity"] + result["specificity"]) / 2)
    auc, low, high = grouped_bootstrap_auc(labels, scores, groups, n_boot=150, seed=7)
    assert result["auc"] == auc
    assert result["auc_ci95_group_bootstrap"] == (low, high)
