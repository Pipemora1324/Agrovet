import numpy as np
import pandas as pd
import pytest

from generate_dataset import DatasetParams, generate
from train_lstm import best_f1_threshold, build_model, early_warning_stats, split_cows


def test_split_has_no_cow_leakage_and_is_stratified():
    df = generate(DatasetParams())
    train, val, test = split_cows(df)
    assert not (train & val or train & test or val & test)
    assert (len(train), len(val), len(test)) == (420, 90, 90)
    sick = df.groupby("cow_id")["sick"].first()
    for ids in (train, val, test):
        assert sick.loc[list(ids)].mean() == pytest.approx(0.35, abs=0.01)


def test_split_is_reproducible():
    df = generate(DatasetParams(n_cows=100))
    assert split_cows(df) == split_cows(df)


def test_model_architecture():
    model = build_model()
    assert model.input_shape == (None, 14, 3)
    assert model.output_shape == (None, 1)
    assert [layer.name for layer in model.layers[1:]] == ["lstm", "dropout", "dense", "probability"]
    assert build_model(batch_size=1).input_shape == (1, 14, 3)


def test_best_f1_threshold_separates_perfect_scores():
    y = np.array([0, 0, 0, 1, 1])
    prob = np.array([0.1, 0.2, 0.3, 0.8, 0.9])
    threshold = best_f1_threshold(y, prob)
    assert 0.3 < threshold <= 0.8


def test_early_warning_stats():
    meta = pd.DataFrame({
        "cow_id": [1, 1, 1, 2, 2, 3, 3],
        "end_day": [20, 21, 22, 20, 21, 20, 21],
        "days_to_onset": [5, 4, 3, 2, 1, np.nan, np.nan],
        "sick": [True, True, True, True, True, False, False],
    })
    prob = np.array([0.1, 0.9, 0.95, 0.2, 0.3, 0.7, 0.1])
    stats = early_warning_stats(meta, prob, threshold=0.5)
    assert stats["early_warning"]["sick_cows"] == 2
    assert stats["early_warning"]["detected_cows"] == 1
    assert stats["early_warning"]["median_anticipation_days"] == 4.0
    assert stats["false_alarms"]["healthy_cows_with_alert"] == 1
    assert stats["false_alarms"]["alert_windows"] == 1
    assert stats["false_alarms"]["alert_rate_per_window"] == 0.5
