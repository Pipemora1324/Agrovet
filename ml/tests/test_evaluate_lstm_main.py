"""Corrida de punta a punta de evaluate_lstm.main() con el TFLite desplegado y un dataset sintético
pequeño. Las salidas van a una carpeta temporal: no toca reports/ ni el modelo."""

import hashlib
import json

import numpy as np
import pytest

import evaluate_lstm
from lstm_evaluation import FARMS

pytestmark = pytest.mark.skipif(not evaluate_lstm.TFLITE_PATH.exists(), reason="Modelo aún no exportado")


@pytest.fixture(scope="module")
def run(tmp_path_factory):
    out = tmp_path_factory.mktemp("reports")
    model_digest = hashlib.sha256(evaluate_lstm.TFLITE_PATH.read_bytes()).hexdigest()
    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(evaluate_lstm, "REPORTS_DIR", out)
        evaluate_lstm.main(["--n-cows", "60", "--farm-cows", "20", "--n-boot", "20", "--repeats", "2",
                            "--perm-repeats", "2"])
    report = json.loads((out / evaluate_lstm.REPORT_NAME).read_text(encoding="utf-8"))
    return out, report, model_digest


def test_outputs_are_written_and_declared_synthetic(run):
    out, report, _ = run
    assert (out / evaluate_lstm.CALIBRATION_FIGURE).stat().st_size > 10_000
    assert (out / evaluate_lstm.THRESHOLD_FIGURE).stat().st_size > 10_000
    assert "SINTÉTICOS" in report["note"]
    assert "validez clínica" in report["note"]
    assert report["data"]["params"] == "DatasetParams(n_cows=60)"
    text = json.dumps(report, ensure_ascii=False)
    assert "C:\\" not in text
    assert "/home/" not in text


def test_uses_the_deployed_model_without_changing_it(run):
    _, report, digest_before = run
    model = report["model"]
    assert model["sha256"] == digest_before
    assert hashlib.sha256(evaluate_lstm.TFLITE_PATH.read_bytes()).hexdigest() == digest_before
    assert model["sha256_matches_config"] is True
    assert model["threshold_red"] == pytest.approx(0.854394)
    assert model["threshold_yellow"] == pytest.approx(0.427197)


def test_split_by_cow_and_baselines(run):
    _, report, _ = run
    data = report["data"]
    assert sum(data[p]["cows"] for p in ("train", "val", "test")) == 60
    test = report["baselines"]["test"]
    assert set(test) == {"lstm", "umbral_temperatura", "regresion_logistica", "random_forest"}
    assert test["lstm"]["threshold"] == pytest.approx(0.854394)
    for name, model in test.items():
        low, high = model["f1_ci95"]
        assert 0 <= low <= high <= 1, name
        assert sum(model["confusion"].values()) == data["test"]["windows"]
        assert ("f1_minus_lstm_ci95" in model) == (name != "lstm")


def test_robustness_table(run):
    _, report, _ = run
    rows = report["robustness"]["table"]
    kinds = [r["degradation"] for r in rows]
    assert kinds[0] == "sin_degradar"
    assert kinds.count("ruido_gaussiano") == 4
    assert kinds.count("faltan_ultimos_dias") == 4
    assert rows[0]["coverage"] == 1.0
    assert rows[0]["draws"] == 1
    noise = [r for r in rows if r["degradation"] == "ruido_gaussiano"]
    assert all(r["draws"] == 2 for r in noise)
    cells = [r for r in rows if r["degradation"] == "faltantes_celdas"]
    # Con más datos faltantes el preprocesamiento acepta menos ventanas
    assert cells[0]["coverage"] > cells[-1]["coverage"]
    for r in rows:
        low, high = r["f1_range"]
        assert low <= r["f1"] <= high


def test_farm_shift_calibration_thresholds_and_importance(run):
    _, report, _ = run
    assert set(report["farm_shift"]) == set(FARMS)
    combined = report["farm_shift"]["otra_finca_combinada"]
    assert combined["changes"]["base_temp_mean"] == 38.8
    assert combined["windows"] > 0
    assert set(combined["models"]) == {"lstm", "umbral_temperatura", "regresion_logistica", "random_forest"}

    calibration = report["calibration"]
    assert 0 <= calibration["ece_10_bins"] <= 1
    assert sum(b["count"] for b in calibration["bins"]) == report["data"]["test"]["windows"]

    red = report["thresholds"]["red"]
    assert [r["threshold"] for r in red] == list(evaluate_lstm.RED_TABLE)
    recalls = [r["recall"] for r in red]
    assert recalls == sorted(recalls, reverse=True)
    yellow = report["thresholds"]["yellow"]
    shares = [r["healthy_windows_yellow_or_red"] for r in yellow]
    assert shares == sorted(shares, reverse=True)

    importance = report["permutation_importance"]["features"]
    assert set(importance) == {"temperature_c", "milk_l", "feed_kg"}


def test_rounded_handles_nested_values():
    value = {"a": [np.float64(0.12345678), float("nan")], "b": (np.int64(3), "x"), "c": 1.0}
    assert evaluate_lstm.rounded(value) == {"a": [0.123457, None], "b": [3, "x"], "c": 1.0}
    assert evaluate_lstm.rounded(0.123456, digits=2) == 0.12
