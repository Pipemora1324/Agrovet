"""Calibración, confusión por grado, intervalos por bootstrap agrupado y comparación pareada."""

import numpy as np
import pytest

from milk_evaluation import (
    brier_score,
    calibration_bins,
    expected_calibration_error,
    full_report,
    grade_confusion,
    grouped_bootstrap_rates,
    paired_auc_difference,
)


def test_calibration_bins_by_hand():
    labels = [0, 0, 1, 1, 1]
    probs = [0.05, 0.15, 0.15, 0.95, 1.0]

    bins = calibration_bins(labels, probs, n_bins=10)

    assert [(b["low"], b["count"]) for b in bins] == [(0.0, 1), (0.1, 2), (0.9, 2)]
    assert bins[1]["mean_probability"] == pytest.approx(0.15)
    assert bins[1]["fraction_abnormal"] == 0.5
    assert bins[2]["high"] == 1.0
    assert bins[2]["fraction_abnormal"] == 1.0


def test_ece_by_hand():
    labels = [0, 0, 1, 1, 1]
    probs = [0.05, 0.15, 0.15, 0.95, 1.0]
    # |0.05-0| * 1/5 + |0.15-0.5| * 2/5 + |0.975-1| * 2/5
    assert expected_calibration_error(labels, probs) == pytest.approx(0.01 + 0.14 + 0.01)


def test_ece_is_zero_when_frequencies_match_and_large_when_overconfident():
    labels = [0] * 8 + [1] * 2
    assert expected_calibration_error(labels, [0.2] * 10) == pytest.approx(0.0)
    # Cada pozo en su intervalo: 1/2 * |0.99 - 0| + 1/2 * |0.01 - 1|
    assert expected_calibration_error([0, 1], [0.99, 0.01]) == pytest.approx(0.99)


def test_brier():
    assert brier_score([0, 1], [0.0, 1.0]) == 0.0
    assert brier_score([0, 1], [0.5, 0.5]) == 0.25
    assert brier_score([1, 1], [0.0, 0.5]) == pytest.approx((1 + 0.25) / 2)


def test_grade_confusion_counts_each_original_grade():
    grades = ["Normal Milk", "Normal Milk", "Blood tinged Milk", "Watery Milk", "Watery Milk", "Watery Milk"]
    preds = [0, 1, 1, 1, 0, 1]

    table = grade_confusion(grades, preds)

    assert table["Normal Milk"] == {
        "n": 2,
        "predicted_normal": 1,
        "predicted_abnormal": 1,
        "fraction_abnormal": 0.5,
    }
    assert table["Blood tinged Milk"]["predicted_abnormal"] == 1
    assert table["Watery Milk"] == {
        "n": 3,
        "predicted_normal": 1,
        "predicted_abnormal": 2,
        "fraction_abnormal": pytest.approx(2 / 3),
    }
    assert list(table) == ["Blood tinged Milk", "Normal Milk", "Watery Milk"]


def clustered(seed=0, n_groups=30):
    rng = np.random.default_rng(seed)
    groups = np.repeat(np.arange(n_groups), 4)
    labels = (groups % 2).astype(int)
    # Errores concentrados en algunos grupos completos: así se ve la diferencia con Wilson
    wrong_groups = rng.choice(n_groups, size=6, replace=False)
    preds = np.where(np.isin(groups, wrong_groups), 1 - labels, labels)
    scores = np.clip(preds * 0.6 + rng.uniform(0, 0.4, len(labels)), 0, 1)
    return labels, preds, scores, groups


def test_grouped_bootstrap_rates_contain_the_point_and_are_reproducible():
    labels, preds, _, groups = clustered()
    rates = grouped_bootstrap_rates(labels, preds, groups, n_boot=400, seed=3)

    sensitivity = np.mean(preds[labels == 1] == 1)
    specificity = np.mean(preds[labels == 0] == 0)
    assert rates["sensitivity"][0] <= sensitivity <= rates["sensitivity"][1]
    assert rates["specificity"][0] <= specificity <= rates["specificity"][1]
    assert rates == grouped_bootstrap_rates(labels, preds, groups, n_boot=400, seed=3)
    assert rates != grouped_bootstrap_rates(labels, preds, groups, n_boot=400, seed=4)


def test_grouped_bootstrap_is_wider_than_ignoring_the_groups():
    labels, preds, _, groups = clustered()
    grouped = grouped_bootstrap_rates(labels, preds, groups, n_boot=600, seed=1)["sensitivity"]
    independent = grouped_bootstrap_rates(labels, preds, np.arange(len(labels)), n_boot=600, seed=1)[
        "sensitivity"
    ]
    assert grouped[1] - grouped[0] > independent[1] - independent[0]


def test_perfect_predictions_give_a_degenerate_interval():
    labels = np.array([0, 1] * 10)
    rates = grouped_bootstrap_rates(labels, labels, np.arange(20), n_boot=100, seed=0)
    assert rates == {"sensitivity": (1.0, 1.0), "specificity": (1.0, 1.0)}


def test_paired_difference_is_zero_for_the_same_model_and_signed_otherwise():
    labels, _, scores, groups = clustered()
    same = paired_auc_difference(labels, scores, scores, groups, n_boot=200, seed=0)
    assert same == {"difference": 0.0, "low": 0.0, "high": 0.0}

    worse = np.random.default_rng(5).uniform(0, 1, len(labels))
    better = paired_auc_difference(labels, scores, worse, groups, n_boot=300, seed=0)
    assert better["difference"] > 0
    assert better["low"] <= better["difference"] <= better["high"]
    assert better["low"] > 0
    flipped = paired_auc_difference(labels, worse, scores, groups, n_boot=300, seed=0)
    assert flipped["difference"] == pytest.approx(-better["difference"])


def test_full_report_adds_bootstrap_rates_ece_and_brier():
    labels, _, scores, groups = clustered()
    report = full_report(labels, scores, groups, threshold=0.5, n_boot=100, seed=0)
    for key in (
        "sensitivity",
        "specificity",
        "auc",
        "sensitivity_ci95",
        "auc_ci95_group_bootstrap",
        "sensitivity_ci95_group_bootstrap",
        "specificity_ci95_group_bootstrap",
        "ece",
        "brier",
    ):
        assert key in report
    assert report["ece"] == pytest.approx(expected_calibration_error(labels, scores))
    assert report["brier"] == pytest.approx(brier_score(labels, scores))
    low, high = report["sensitivity_ci95_group_bootstrap"]
    assert low <= report["sensitivity"] <= high
