import numpy as np
import pytest

from cnn_evaluation import (balanced_class_weight, confusion, grouped_bootstrap_auc,
                            inner_validation_split, repeated_group_folds, summarize, wilson_interval)


def _toy(n_groups=40, seed=0):
    """Grupos de 1 a 4 fotos con la misma etiqueta por grupo (como una vaca)."""
    rng = np.random.default_rng(seed)
    labels, groups = [], []
    for g in range(n_groups):
        size = int(rng.integers(1, 5))
        labels += [g % 2] * size
        groups += [g] * size
    return np.array(labels), np.array(groups)


def test_no_group_is_split_between_train_and_test():
    labels, groups = _toy()
    for _, _, train_idx, test_idx in repeated_group_folds(labels, groups, n_splits=5, n_repeats=5):
        assert not set(groups[train_idx]) & set(groups[test_idx])


def test_every_image_is_tested_exactly_once_per_repetition():
    labels, groups = _toy()
    folds = repeated_group_folds(labels, groups, n_splits=5, n_repeats=3)
    assert len(folds) == 15
    for rep in range(3):
        tested = np.concatenate([test for r, _, _, test in folds if r == rep])
        assert sorted(tested) == list(range(len(labels)))


def test_folds_are_stratified_and_repetitions_differ():
    labels, groups = _toy()
    folds = repeated_group_folds(labels, groups, n_splits=5, n_repeats=2)
    for _, _, _, test_idx in folds:
        assert 0 < labels[test_idx].mean() < 1
    assert not np.array_equal(folds[0][3], folds[5][3])


def test_inner_validation_keeps_groups_apart_and_stays_inside_train():
    labels, groups = _toy()
    _, _, train_idx, test_idx = repeated_group_folds(labels, groups)[0]
    fit_idx, val_idx = inner_validation_split(labels, groups, train_idx, seed=3)
    assert set(fit_idx) | set(val_idx) == set(train_idx)
    assert not set(groups[fit_idx]) & set(groups[val_idx])
    assert not set(val_idx) & set(test_idx)


def test_wilson_interval_matches_the_reference_values():
    low, high = wilson_interval(8, 10)
    assert (low, high) == pytest.approx((0.4902, 0.9433), abs=1e-4)
    assert wilson_interval(0, 10)[0] == 0.0
    assert wilson_interval(10, 10)[1] == pytest.approx(1.0)


def test_confusion_and_class_weights():
    assert confusion([0, 0, 1, 1, 1], [0, 1, 1, 0, 1]) == {"tn": 1, "fp": 1, "fn": 1, "tp": 2}
    weights = balanced_class_weight([0, 1, 1, 1])
    assert weights == pytest.approx({0: 2.0, 1: 2 / 3})


def test_group_bootstrap_auc_interval_contains_the_estimate():
    labels, groups = _toy(60)
    rng = np.random.default_rng(1)
    scores = labels * 0.3 + rng.random(len(labels)) * 0.7
    auc, low, high = grouped_bootstrap_auc(labels, scores, groups, n_boot=300)
    assert 0.5 < auc <= 1.0
    assert low <= auc <= high
    perfect = grouped_bootstrap_auc(labels, labels.astype(float), groups, n_boot=50)
    assert perfect == (1.0, 1.0, 1.0)


def test_summarize_reports_sensitivity_specificity_and_confusion():
    labels = np.array([0, 0, 0, 0, 1, 1, 1, 1])
    scores = np.array([0.1, 0.2, 0.6, 0.3, 0.9, 0.8, 0.4, 0.7])
    result = summarize(labels, scores, np.arange(8), threshold=0.5, n_boot=50)
    assert result["confusion"] == {"tn": 3, "fp": 1, "fn": 1, "tp": 3}
    assert result["sensitivity"] == result["specificity"] == 0.75
    assert result["sensitivity_ci95"] == pytest.approx(wilson_interval(3, 4))
    assert result["n_groups"] == 8
