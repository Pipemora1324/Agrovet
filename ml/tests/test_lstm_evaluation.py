"""Pruebas de lstm_evaluation con datos sintéticos pequeños y modelos de juguete (sin TensorFlow)."""

import dataclasses

import numpy as np
import pandas as pd
import pytest
from sklearn.metrics import f1_score, precision_score, recall_score, roc_auc_score

from generate_dataset import DatasetParams, generate
from lstm_evaluation import (
    FARMS,
    NOISE_UNITS,
    add_noise,
    binary_metrics,
    cow_level,
    degradation_row,
    drop_values,
    fit_baselines,
    flatten,
    grouped_bootstrap,
    missing_days,
    permutation_importance,
    preprocess_batch,
    raw_windows,
    temperature_score,
    threshold_sweep,
    yellow_sweep,
)
from preprocess import TEMP_SCALE, build_windows


@pytest.fixture(scope="module")
def small():
    return generate(DatasetParams(n_cows=30))


@pytest.fixture(scope="module")
def windows(small):
    return raw_windows(small)


def plain_raw(n=50, seed=0):
    """Ventanas crudas sin faltantes alrededor de 38,6 °C, 13 L y 11 kg."""
    rng = np.random.default_rng(seed)
    base = np.array([38.6, 13.0, 11.0])
    return base + rng.normal(0, [0.1, 0.5, 0.5], (n, 14, 3))


def test_raw_windows_match_build_windows(small, windows):
    raw, labels, meta = windows
    X, usable = preprocess_batch(raw)
    X_ref, y_ref, meta_ref = build_windows(small)
    assert usable.all()
    np.testing.assert_allclose(X, X_ref, atol=1e-6)
    np.testing.assert_array_equal(labels, y_ref)
    pd.testing.assert_frame_equal(meta, meta_ref)
    assert raw.shape == (len(labels), 14, 3)
    # Las ventanas crudas conservan los errores de digitación (por ejemplo, datos vacíos)
    assert np.isnan(raw).any()


def test_preprocess_batch_marks_unusable_windows():
    raw = plain_raw(3)
    raw[1, :5, 2] = np.nan  # 9 días válidos de alimento: menos de 10
    X, usable = preprocess_batch(raw)
    assert usable.tolist() == [True, False, True]
    assert (X[1] == 0).all()
    assert X.dtype == np.float32
    assert X[0, :7, 0].mean() == pytest.approx(0.0, abs=1e-5)


def test_noise_has_the_documented_scale():
    raw = plain_raw(400)
    assert np.array_equal(add_noise(raw, 0.0, np.random.default_rng(0)), raw)
    noisy = add_noise(raw, 2.0, np.random.default_rng(1))
    assert np.std(noisy[..., 0] - raw[..., 0]) == pytest.approx(2 * NOISE_UNITS[0], rel=0.05)
    assert np.std(noisy[..., 1] / raw[..., 1] - 1) == pytest.approx(2 * NOISE_UNITS[1], rel=0.05)
    assert np.std(noisy[..., 2] / raw[..., 2] - 1) == pytest.approx(2 * NOISE_UNITS[2], rel=0.05)
    with_gap = raw.copy()
    with_gap[0, 3, 1] = np.nan
    assert np.isnan(add_noise(with_gap, 1.0, np.random.default_rng(2))[0, 3, 1])
    assert not np.isnan(raw).any()  # no modifica la entrada


def test_drop_values_cells_and_whole_days():
    raw = plain_raw(500)
    cells = drop_values(raw, 0.2, np.random.default_rng(0))
    assert np.isnan(cells).mean() == pytest.approx(0.2, abs=0.01)
    assert np.isnan(cells).any(axis=2).mean() > 0.4  # las celdas caen en días distintos
    days = drop_values(raw, 0.3, np.random.default_rng(0), whole_days=True)
    missing = np.isnan(days)
    assert missing.mean() == pytest.approx(0.3, abs=0.01)
    assert (missing.all(axis=2) == missing.any(axis=2)).all()
    assert not np.isnan(drop_values(raw, 0.0, np.random.default_rng(0))).any()
    assert not np.isnan(raw).any()


def test_missing_days_at_start_and_end():
    raw = plain_raw(4)
    start = missing_days(raw, 3, "start")
    end = missing_days(raw, 2, "end")
    assert np.isnan(start[:, :3]).all()
    assert not np.isnan(start[:, 3:]).any()
    assert np.isnan(end[:, -2:]).all()
    assert not np.isnan(end[:, :-2]).any()
    assert np.array_equal(missing_days(raw, 0, "end"), raw)
    assert not np.isnan(raw).any()
    with pytest.raises(ValueError, match="where"):
        missing_days(raw, 1, "middle")


def test_missing_last_days_hide_the_recent_signal():
    # Con los últimos días vacíos se repite el último valor válido: la subida final se pierde
    raw = plain_raw(1)
    raw[0, -2:, 0] += 1.5
    X_full, _ = preprocess_batch(raw)
    X_cut, usable = preprocess_batch(missing_days(raw, 2, "end"))
    assert usable.all()
    assert X_full[0, -1, 0] > 2.5
    assert X_cut[0, -1, 0] < 1.0


def test_temperature_score_and_flatten():
    X = np.zeros((2, 14, 3))
    X[0, -1, 0], X[1, -1, 0], X[1, -2, 0] = 2.0, -1.0, 5.0
    np.testing.assert_allclose(temperature_score(X), [2.0 * TEMP_SCALE, -1.0 * TEMP_SCALE])
    assert flatten(X).shape == (2, 42)
    np.testing.assert_array_equal(flatten(X)[0, -3:], X[0, -1])


def test_baselines_learn_a_separable_signal():
    rng = np.random.default_rng(0)
    y = np.repeat([0, 1], 100)
    X = rng.normal(0, 1, (200, 14, 3))
    X[y == 1, -3:, 1] -= 3.0  # la leche cae en los últimos días de las ventanas de riesgo
    models = fit_baselines(X, y, seed=1)
    assert set(models) == {"umbral_temperatura", "regresion_logistica", "random_forest"}
    for name in ("regresion_logistica", "random_forest"):
        scores = models[name](X)
        assert scores.shape == (200,)
        assert roc_auc_score(y, scores) > 0.95
    # La temperatura no lleva la señal en estos datos
    assert roc_auc_score(y, models["umbral_temperatura"](X)) < 0.7


def test_binary_metrics_match_sklearn():
    rng = np.random.default_rng(3)
    y = rng.integers(0, 2, 300)
    scores = np.clip(y * 0.3 + rng.uniform(0, 0.7, 300), 0, 1)
    m = binary_metrics(y, scores, 0.5)
    preds = (scores >= 0.5).astype(int)
    assert m["f1"] == pytest.approx(f1_score(y, preds))
    assert m["precision"] == pytest.approx(precision_score(y, preds))
    assert m["recall"] == pytest.approx(recall_score(y, preds))
    assert m["auc"] == pytest.approx(roc_auc_score(y, scores))
    cm = m["confusion"]
    assert m["specificity"] == pytest.approx(cm["tn"] / (cm["tn"] + cm["fp"]))
    assert sum(cm.values()) == 300


def test_binary_metrics_edge_cases():
    # El umbral es inclusivo
    assert binary_metrics([0, 1], [0.2, 0.5], 0.5)["confusion"] == {"tn": 1, "fp": 0, "fn": 0, "tp": 1}
    none = binary_metrics([0, 1, 1], [0.1, 0.2, 0.3], 0.9)
    assert (none["f1"], none["precision"], none["recall"], none["specificity"]) == (0.0, 0.0, 0.0, 1.0)
    single = binary_metrics([0, 0], [0.1, 0.9], 0.5)
    assert np.isnan(single["auc"])
    assert single["recall"] == 0.0
    assert single["f1"] == 0.0
    assert binary_metrics([1, 1], [0.6, 0.7], 0.5)["specificity"] == 0.0
    perfect = binary_metrics([0, 1], [0.1, 0.9], 0.5)
    assert (perfect["f1"], perfect["precision"], perfect["auc"]) == (1.0, 1.0, 1.0)


def reference_bootstrap(labels, scores, threshold, groups, n_boot, seed):
    rng = np.random.default_rng(seed)
    unique = np.unique(groups)
    f1s = []
    for _ in range(n_boot):
        idx = np.concatenate([np.flatnonzero(groups == g) for g in rng.choice(unique, len(unique))])
        if len(np.unique(labels[idx])) < 2:
            continue
        f1s.append(f1_score(labels[idx], (scores[idx] >= threshold).astype(int), zero_division=0))
    return tuple(np.percentile(f1s, [2.5, 97.5]))


def test_grouped_bootstrap_follows_the_reference_and_pairs_models():
    rng = np.random.default_rng(5)
    groups = np.repeat(np.arange(25), 8)
    labels = (rng.uniform(size=200) < 0.3).astype(int)
    good = np.clip(labels * 0.4 + rng.uniform(0, 0.6, 200), 0, 1)
    bad = rng.uniform(size=200)
    result = grouped_bootstrap(labels, {"a": good, "b": bad, "c": good}, {"a": 0.5, "b": 0.5, "c": 0.5},
                               groups, reference="a", n_boot=300, seed=2)
    assert result["a"]["f1_ci95"] == pytest.approx(reference_bootstrap(labels, good, 0.5, groups, 300, 2))
    assert "f1_minus_a_ci95" not in result["a"]
    assert set(result["b"]) == {"f1_ci95", "auc_ci95", "recall_ci95", "precision_ci95",
                                "f1_minus_a_ci95", "auc_minus_a_ci95", "recall_minus_a_ci95"}
    assert result["c"]["auc_minus_a_ci95"] == (0.0, 0.0)
    assert result["b"]["auc_minus_a_ci95"][1] < 0
    low, high = result["a"]["auc_ci95"]
    assert low < roc_auc_score(labels, good) < high
    again = grouped_bootstrap(labels, {"a": good}, {"a": 0.5}, groups, reference="a", n_boot=300, seed=2)
    assert again["a"] == result["a"]


def test_grouped_bootstrap_skips_single_class_samples():
    labels = np.array([0, 0, 1, 1])
    groups = np.array([0, 0, 1, 1])  # cada vaca tiene una sola clase
    scores = np.array([0.1, 0.2, 0.8, 0.9])
    result = grouped_bootstrap(labels, {"m": scores}, {"m": 0.5}, groups, reference="m", n_boot=200, seed=0)
    assert result["m"]["auc_ci95"] == (1.0, 1.0)
    assert result["m"]["f1_ci95"] == (1.0, 1.0)


def test_cow_level_matches_train_lstm_definition():
    # train_lstm carga TensorFlow, que no está en el entorno de mutmut
    pytest.importorskip("tensorflow")
    from train_lstm import early_warning_stats

    meta = pd.DataFrame({
        "cow_id": [1, 1, 1, 2, 2, 3, 3, 4],
        "end_day": [20, 21, 22, 20, 21, 20, 21, 20],
        "days_to_onset": [7, 4, 3, 2, 1, np.nan, np.nan, np.nan],
        "sick": [True, True, True, True, True, False, False, False],
    })
    prob = np.array([0.95, 0.1, 0.95, 0.2, 0.3, 0.7, 0.1, 0.2])
    level = cow_level(meta, prob, 0.5)
    reference = early_warning_stats(meta, prob, 0.5)
    # La alerta 7 días antes no cuenta: solo las de 1 a 5 días
    assert level["sick_cows_detected_rate"] == reference["early_warning"]["detection_rate"] == 0.5
    assert level["healthy_cows_with_alert_rate"] == pytest.approx(
        reference["false_alarms"]["healthy_cows_with_alert_rate"], abs=1e-4)
    assert level["healthy_cows_with_alert_rate"] == pytest.approx(0.5)
    assert (level["sick_cows"], level["healthy_cows"]) == (2, 2)


def test_cow_level_without_sick_or_healthy_cows():
    meta = pd.DataFrame({"cow_id": [1], "end_day": [20], "days_to_onset": [np.nan], "sick": [False]})
    level = cow_level(meta, np.array([0.9]), 0.5)
    assert np.isnan(level["sick_cows_detected_rate"])
    assert level["healthy_cows_with_alert_rate"] == 1.0
    sick = pd.DataFrame({"cow_id": [1], "end_day": [20], "days_to_onset": [2.0], "sick": [True]})
    assert np.isnan(cow_level(sick, np.array([0.9]), 0.5)["healthy_cows_with_alert_rate"])


def test_degradation_row_counts_unevaluated_risk_windows_as_missed():
    labels = np.array([1, 1, 1, 1, 0, 0])
    scores = np.array([0.9, 0.9, 0.0, 0.0, 0.1, 0.2])
    usable = np.array([True, True, False, False, True, True])
    row = degradation_row(labels, scores, usable, 0.5)
    assert row["coverage"] == pytest.approx(4 / 6)
    assert row["recall"] == 1.0
    assert row["recall_all_windows"] == 0.5
    assert row["confusion"] == {"tn": 2, "fp": 0, "fn": 0, "tp": 2}
    assert np.isnan(degradation_row([0, 0], [0.1, 0.2], [True, True], 0.5)["recall_all_windows"])


def test_threshold_sweep_and_yellow_sweep():
    labels = np.array([0, 0, 0, 0, 1, 1])
    scores = np.array([0.1, 0.3, 0.5, 0.7, 0.6, 0.9])
    meta = pd.DataFrame({"cow_id": [1, 1, 2, 2, 3, 3], "end_day": [0] * 6,
                         "days_to_onset": [np.nan] * 4 + [2.0, 1.0], "sick": [False] * 4 + [True] * 2})
    rows = threshold_sweep(labels, scores, meta, [0.5, 0.8])
    assert [r["threshold"] for r in rows] == [0.5, 0.8]
    assert "auc" not in rows[0]
    assert rows[0]["confusion"] == {"tn": 2, "fp": 2, "fn": 0, "tp": 2}
    assert rows[1]["recall"] == 0.5
    assert rows[0]["healthy_cows_with_alert_rate"] == 0.5
    assert rows[1]["healthy_cows_with_alert_rate"] == 0.0
    yellow = yellow_sweep(labels, scores, red_threshold=0.8, yellow_thresholds=[0.3, 0.65])
    assert yellow[0] == {"yellow_threshold": 0.3, "risk_windows_yellow_or_red": 1.0,
                         "healthy_windows_yellow": 0.75, "healthy_windows_yellow_or_red": 0.75}
    assert yellow[1]["risk_windows_yellow_or_red"] == 0.5
    assert yellow[1]["healthy_windows_yellow"] == 0.25


def test_permutation_importance_finds_the_only_informative_variable():
    rng = np.random.default_rng(0)
    labels = np.repeat([0, 1], 150)
    X = rng.normal(0, 1, (300, 14, 3))
    X[labels == 1, :, 0] += 2.0

    def predict(windows):
        return 1 / (1 + np.exp(-windows[:, :, 0].mean(axis=1) * 3 + 3))

    result = permutation_importance(predict, X, labels, 0.5, n_repeats=10, seed=1)
    assert set(result) == {"temperature_c", "milk_l", "feed_kg"}
    assert result["temperature_c"]["auc_drop_mean"] > 0.3
    assert result["temperature_c"]["f1_drop_mean"] > 0.3
    low, high = result["temperature_c"]["auc_drop_ci95"]
    assert 0 < low <= high
    for name in ("milk_l", "feed_kg"):
        assert result[name]["auc_drop_mean"] == 0.0
        assert result[name]["f1_drop_sd"] == 0.0
    again = permutation_importance(predict, X, labels, 0.5, n_repeats=10, seed=1)
    assert again == result


def test_farms_are_valid_dataset_parameters():
    fields = {f.name for f in dataclasses.fields(DatasetParams)}
    assert FARMS["misma_finca_otras_vacas"] == {}
    for name, overrides in FARMS.items():
        assert set(overrides) <= fields, name
        DatasetParams(**overrides)
    combined = FARMS["otra_finca_combinada"]
    for name in ("alta_produccion", "clima_calido", "registros_ruidosos", "subclinica_corta_y_leve"):
        assert FARMS[name].items() <= combined.items()
    assert combined["base_temp_mean"] != DatasetParams.base_temp_mean
