"""Comprueba que los artefactos versionados que usa la app son coherentes entre sí."""

import hashlib
import json
from pathlib import Path

import numpy as np
import pytest

from preprocess import FEATURES, WINDOW_DAYS, preprocess_window, traffic_light

MODELS_DIR = Path(__file__).resolve().parents[1] / "models"
TFLITE_PATH = MODELS_DIR / "mastitis_lstm.tflite"
CONFIG_PATH = MODELS_DIR / "model_config.json"
VECTORS_PATH = MODELS_DIR / "test_vectors.json"

pytestmark = pytest.mark.skipif(not TFLITE_PATH.exists(), reason="Modelo aún no exportado")


@pytest.fixture(scope="module")
def config():
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


@pytest.fixture(scope="module")
def vectors():
    return json.loads(VECTORS_PATH.read_text(encoding="utf-8"))


@pytest.fixture(scope="module")
def interpreter():
    from export_tflite import make_interpreter
    return make_interpreter(TFLITE_PATH.read_bytes())


def to_raw(window):
    return np.array([[np.nan if v is None else v for v in day] for day in window], dtype=np.float64)


def test_config_matches_model_file(config, vectors):
    digest = hashlib.sha256(TFLITE_PATH.read_bytes()).hexdigest()
    assert config["tflite_sha256"] == digest
    assert vectors["tflite_sha256"] == digest
    assert config["input"]["shape"] == [1, WINDOW_DAYS, len(FEATURES)]
    assert config["trained_on"] == "synthetic"


def test_traffic_light_ranges_follow_threshold(config):
    threshold = config["threshold"]
    lights = config["traffic_light"]
    assert lights["yellow"]["min"] == pytest.approx(threshold * 0.5)
    assert lights["red"]["min"] == threshold
    assert lights["green"]["max_exclusive"] == lights["yellow"]["min"]


def test_model_uses_only_builtin_ops(interpreter):
    ops = {op["op_name"] for op in interpreter._get_ops_details()}
    assert not any(op.startswith("Flex") for op in ops)


def test_vectors_cover_all_kinds(vectors):
    kinds = [case["kind"] for case in vectors["cases"]]
    assert len(kinds) == 8
    assert {k: kinds.count(k) for k in set(kinds)} == {
        "healthy": 2, "subclinical": 2, "estrus": 2, "erroneous_record": 2}


def test_preprocessing_reproduces_vectors(vectors):
    for case in vectors["cases"]:
        normalized = preprocess_window(to_raw(case["raw_window"]))
        np.testing.assert_allclose(normalized, case["expected_normalized"], atol=1e-9,
                                   err_msg=case["id"])


def test_tflite_reproduces_vectors(vectors, interpreter):
    from export_tflite import run_tflite

    for case in vectors["cases"]:
        window = np.array(case["expected_normalized"], dtype=np.float32)[np.newaxis]
        probability = float(run_tflite(interpreter, window)[0])
        assert probability == pytest.approx(case["expected_probability"], abs=vectors["tolerance"])
        assert traffic_light(probability, vectors["threshold"]) == case["expected_color"]
