"""Paridad Keras frente a TFLite de la CNN de la ubre.

Las dos primeras pruebas usan un modelo sin pesos preentrenados (no descargan nada). La última
verifica el modelo exportado que usa la app contra los vectores guardados al exportarlo."""

import json
from pathlib import Path

import numpy as np
import pytest

from train_cnn import build_cnn, export_tflite, tflite_predict
from train_udder_public import PATTERNS, synthetic_pattern

MODELS = Path(__file__).resolve().parents[1] / "models"


@pytest.fixture(scope="module")
def small_model():
    import tensorflow as tf

    tf.keras.utils.set_random_seed(0)
    model, _ = build_cnn(weights=None)
    return model


def test_synthetic_patterns_are_deterministic_images():
    for kind in PATTERNS:
        image = synthetic_pattern(kind)
        assert image.shape == (224, 224, 3) and image.dtype == np.uint8
        assert np.array_equal(image, synthetic_pattern(kind))
    assert not np.array_equal(synthetic_pattern(0), synthetic_pattern(1))


def test_float_export_matches_keras(small_model, tmp_path):
    images = np.stack([synthetic_pattern(k) for k in PATTERNS])
    path = tmp_path / "m.tflite"
    export_tflite(small_model, path)
    keras_out = small_model.predict(images.astype(np.float32), verbose=0).ravel()
    lite_out = tflite_predict(path, images)
    assert np.abs(keras_out - lite_out).max() < 1e-4


def test_quantized_export_is_smaller_and_returns_probabilities(small_model, tmp_path):
    images = np.stack([synthetic_pattern(k) for k in PATTERNS])
    float_size = export_tflite(small_model, tmp_path / "f.tflite")
    quant_size = export_tflite(small_model, tmp_path / "q.tflite", quantize=True)
    assert quant_size < float_size / 2
    out = tflite_predict(tmp_path / "q.tflite", images)
    assert np.all((out >= 0) & (out <= 1))


@pytest.mark.skipif(not (MODELS / "udder_cnn.tflite").exists(), reason="modelo de la ubre no exportado")
def test_exported_udder_model_matches_saved_vectors():
    vectors = json.loads((MODELS / "udder_cnn_vectors.json").read_text(encoding="utf-8"))
    config = json.loads((MODELS / "udder_cnn_config.json").read_text(encoding="utf-8"))
    assert config["enabledByDefault"] is False
    assert "no es diagnóstico" in config["disclaimer"]
    images = np.stack([synthetic_pattern(c["pattern"]) for c in vectors["cases"]])
    out = tflite_predict(MODELS / config["modelFile"], images)
    for case, value in zip(vectors["cases"], out):
        assert value == pytest.approx(case["tflite"], abs=1e-5)
        assert abs(value - case["keras"]) <= vectors["tolerance"]
