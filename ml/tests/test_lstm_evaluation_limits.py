"""Límites de lstm_evaluation: casos borde de las métricas, umbrales inclusivos, cálculos exactos con
semilla fija y los hiperparámetros declarados de las líneas base. No usa TensorFlow."""

import numpy as np
import pandas as pd
import pytest

from generate_dataset import DatasetParams, generate
from lstm_evaluation import (
    NOISE_UNITS,
    add_noise,
    baseline_estimators,
    binary_metrics,
    cow_level,
    drop_values,
    missing_days,
    permutation_importance,
    preprocess_batch,
    raw_windows,
    yellow_sweep,
)


def test_raw_windows_skip_unusable_windows_and_keep_going():
    df = generate(DatasetParams(n_cows=1, sick_fraction=0.0, error_fraction=0.0))
    df.loc[df["day"].between(0, 5), "feed_kg"] = np.nan  # las primeras ventanas tienen < 10 días de alimento
    raw, labels, meta = raw_windows(df)
    # Las ventanas que terminan los días 13 y 14 tienen menos de 10 días de alimento; desde la del día 15
    # todas sirven: se saltan las primeras y se sigue con las demás
    assert meta["end_day"].iloc[0] == 15
    assert meta["end_day"].iloc[-1] == 59
    assert len(meta) == 59 - meta["end_day"].iloc[0] + 1
    assert labels.dtype == np.int32
    assert raw.dtype == np.float64
    assert not labels.any()
    assert meta["days_to_onset"].isna().all()


def test_raw_windows_label_horizon_and_onset_cut():
    df = generate(DatasetParams(n_cows=12, sick_fraction=0.5, error_fraction=0.0))
    _, labels, meta = raw_windows(df)
    sick = meta[meta["sick"]]
    assert (sick["days_to_onset"] >= 1).all()  # nada desde el inicio clínico
    positive = labels.astype(bool)
    assert meta.loc[positive, "days_to_onset"].between(1, 5).all()
    assert (meta.loc[~positive & meta["sick"], "days_to_onset"] > 5).all()


def test_preprocess_batch_dtypes():
    raw = np.full((2, 14, 3), [38.6, 13.0, 11.0])
    raw[1, :, 0] = np.nan
    X, usable = preprocess_batch(raw)
    assert X.dtype == np.float32
    assert usable.dtype == bool
    assert usable.tolist() == [True, False]


def test_noise_is_the_exact_documented_formula():
    raw = np.full((3, 14, 3), [38.6, 13.0, 11.0])
    noisy = add_noise(raw, 1.5, np.random.default_rng(7))
    rng = np.random.default_rng(7)
    shape = raw.shape[:-1]
    expected = raw.copy()
    expected[..., 0] += rng.normal(0, 1.5 * NOISE_UNITS[0], shape)
    expected[..., 1] *= 1 + rng.normal(0, 1.5 * NOISE_UNITS[1], shape)
    expected[..., 2] *= 1 + rng.normal(0, 1.5 * NOISE_UNITS[2], shape)
    np.testing.assert_allclose(noisy, expected)
    assert noisy.dtype == np.float64
    assert add_noise(raw.astype(np.float32), 1.0, np.random.default_rng(0)).dtype == np.float64


def test_drop_values_is_the_exact_documented_draw():
    raw = np.ones((4, 14, 3), dtype=np.float32)
    cells = drop_values(raw, 0.25, np.random.default_rng(3))
    expected = np.random.default_rng(3).random(raw.shape) < 0.25
    np.testing.assert_array_equal(np.isnan(cells), expected)
    days = drop_values(raw, 0.25, np.random.default_rng(3), whole_days=True)
    expected_days = np.random.default_rng(3).random(raw.shape[:-1]) < 0.25
    np.testing.assert_array_equal(np.isnan(days).all(axis=2), expected_days)
    assert cells.dtype == np.float64
    assert drop_values(raw, 1.0, np.random.default_rng(0)).size == raw.size
    assert np.isnan(drop_values(raw, 1.0, np.random.default_rng(0))).all()


def test_missing_single_day():
    raw = np.ones((2, 14, 3), dtype=np.float32)
    start = missing_days(raw, 1, "start")
    end = missing_days(raw, 1, "end")
    assert np.isnan(start[:, 0]).all()
    assert np.isnan(start).sum() == 2 * 3
    assert np.isnan(end[:, -1]).all()
    assert np.isnan(end).sum() == 2 * 3
    assert start.dtype == np.float64


def test_baseline_hyperparameters_are_the_declared_ones():
    models = baseline_estimators(seed=9)
    scaler, logistic = (step for _, step in models["regresion_logistica"].steps)
    assert type(scaler).__name__ == "StandardScaler"
    assert logistic.class_weight == "balanced"
    assert logistic.max_iter == 2000
    forest = models["random_forest"].get_params()
    assert forest["n_estimators"] == 300
    assert forest["min_samples_leaf"] == 5
    assert forest["max_features"] == "sqrt"
    assert models["regresion_logistica"].memory is None
    assert forest["class_weight"] == "balanced_subsample"
    assert forest["n_jobs"] == -1
    assert forest["random_state"] == 9
    assert baseline_estimators()["random_forest"].random_state == 42


@pytest.mark.parametrize(("labels", "scores", "expected"), [
    # tp = fp = 1: precisión 0,5
    ([1, 0, 0], [0.9, 0.9, 0.1], {"precision": 0.5, "f1": 2 / 3, "specificity": 0.5}),
    # tp = 1, fn = 1, fp = 0
    ([1, 1, 0], [0.9, 0.1, 0.1], {"precision": 1.0, "f1": 2 / 3, "recall": 0.5}),
    # tp = 1, fp = 1, fn = 0
    ([1, 0], [0.9, 0.9], {"f1": 2 / 3, "specificity": 0.0}),
    # todo negativo y bien predicho: sin F1 que calcular
    ([0, 0], [0.1, 0.2], {"f1": 0.0, "precision": 0.0, "recall": 0.0, "specificity": 1.0}),
])
def test_binary_metrics_small_cases(labels, scores, expected):
    metrics = binary_metrics(labels, scores, 0.5)
    for key, value in expected.items():
        assert metrics[key] == pytest.approx(value), key


def test_cow_level_without_tensorflow():
    meta = pd.DataFrame({
        "cow_id": [1, 1, 2, 2, 3, 3, 4, 5],
        "end_day": [20, 21, 20, 21, 20, 21, 20, 20],
        "days_to_onset": [6.0, 5.0, 3.0, 0.5, 9.0, 1.0, np.nan, np.nan],
        "sick": [True, True, True, True, True, True, False, False],
    })
    # Vaca 1: alerta justo en el umbral 5 días antes (cuenta). Vaca 2: alerta solo a 0,5 días (no
    # cuenta). Vaca 3: alerta a 9 días (no cuenta). Vaca 4: sana con alerta. Vaca 5: sana sin alerta.
    prob = np.array([0.1, 0.5, 0.1, 0.9, 0.9, 0.1, 0.5, 0.4])
    level = cow_level(meta, prob, 0.5)
    assert level == {"sick_cows": 3, "sick_cows_detected_rate": pytest.approx(1 / 3), "healthy_cows": 2,
                     "healthy_cows_with_alert_rate": 0.5}
    everything = cow_level(meta, np.ones(8), 0.5)
    assert everything["sick_cows_detected_rate"] == 1.0
    assert everything["healthy_cows_with_alert_rate"] == 1.0
    nothing = cow_level(meta, np.zeros(8), 0.5)
    assert nothing["sick_cows_detected_rate"] == 0.0
    sick_as_numbers = meta.assign(sick=meta["sick"].astype(int))
    assert cow_level(sick_as_numbers, prob, 0.5) == level


def test_yellow_sweep_red_threshold_is_exclusive_for_yellow():
    labels = np.array([0, 0, 1])
    scores = np.array([0.8, 0.5, 0.9])
    row = yellow_sweep(labels, scores, red_threshold=0.8, yellow_thresholds=[0.5])[0]
    # 0,8 ya es rojo, no amarillo; 0,5 es amarillo (inclusivo)
    assert row["healthy_windows_yellow"] == 0.5
    assert row["healthy_windows_yellow_or_red"] == 1.0


def test_permutation_importance_reports_the_documented_percentiles():
    rng = np.random.default_rng(4)
    labels = rng.integers(0, 2, 120)
    X = rng.normal(0, 1, (120, 14, 3))
    X[:, :, 1] += labels[:, None] * 0.8

    def predict(windows):
        return 1 / (1 + np.exp(-windows[:, :, 1].mean(axis=1) * 2))

    result = permutation_importance(predict, X, labels, 0.5, n_repeats=25, seed=6)
    base = binary_metrics(labels, predict(X), 0.5)
    rng = np.random.default_rng(6)
    drops = []
    for j in range(3):
        for _ in range(25):
            shuffled = X.copy()
            shuffled[:, :, j] = X[rng.permutation(len(X)), :, j]
            if j == 1:
                drops.append(base["auc"] - binary_metrics(labels, predict(shuffled), 0.5)["auc"])
    milk = result["milk_l"]
    assert milk["auc_drop_ci95"] == pytest.approx(tuple(np.percentile(drops, [2.5, 97.5])))
    assert milk["auc_drop_mean"] == pytest.approx(np.mean(drops))
    assert milk["auc_drop_sd"] == pytest.approx(np.std(drops))
