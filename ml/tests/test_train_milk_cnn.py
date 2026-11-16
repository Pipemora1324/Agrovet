"""Prueba de humo del entrenamiento de la red de leche, sin descargar pesos ni datos reales: las dos
arquitecturas se construyen, se entrenan por etapas, Grad-CAM da mapas válidos y el TFLite float16
predice lo mismo que Keras. No mide calidad."""

import numpy as np
import pytest
import tensorflow as tf

from train_cnn import export_tflite
from train_milk_cnn import (
    ARCHITECTURES,
    build_model,
    fit_staged,
    grad_cam,
    overlay,
    tflite_latency,
    tflite_probabilities,
)

SIZE = 64


@pytest.fixture(scope="module")
def toy():
    rng = np.random.default_rng(0)
    images = rng.integers(0, 255, (24, SIZE, SIZE, 3)).astype(np.uint8)
    labels = np.array([0, 1] * 12)
    # La clase se ve en el brillo: suficiente para comprobar que el pipeline aprende algo
    images[labels == 1] = np.clip(images[labels == 1].astype(int) + 60, 0, 255).astype(np.uint8)
    return images, labels


@pytest.mark.parametrize("arch", list(ARCHITECTURES))
def test_both_architectures_train_in_stages_and_explain(arch, toy, tmp_path):
    images, labels = toy
    tf.keras.utils.set_random_seed(0)
    model, backbone = build_model(arch, SIZE, weights=None)
    assert model.input_shape == (None, SIZE, SIZE, 3)
    assert model.output_shape == (None, 1)
    assert not backbone.trainable

    idx = np.arange(len(labels))
    result = fit_staged(
        model,
        backbone,
        arch,
        images,
        labels,
        idx[:16],
        idx[16:20],
        seed=0,
        head_epochs=2,
        tune_epochs=1,
        batch=8,
        predict_idx=idx[20:],
    )

    assert result["head_epochs"] == 2
    assert result["tune_epochs"] == 1
    assert result["frozen"].shape == (4,)
    assert result["tuned"].shape == (4,)
    assert ((result["tuned"] >= 0) & (result["tuned"] <= 1)).all()
    # Etapa 2: solo las últimas capas quedan entrenables
    trainable = [layer for layer in backbone.layers if layer.trainable]
    assert 0 < len(trainable) <= ARCHITECTURES[arch][2]

    cam, prob = grad_cam(model, images[:3].astype(np.float32))
    assert cam.ndim == 3
    assert cam.shape[0] == 3
    assert cam.min() >= 0
    assert cam.max() <= 1 + 1e-6
    np.testing.assert_allclose(
        prob, model.predict(images[:3].astype(np.float32), verbose=0).ravel(), atol=1e-5
    )
    blended = overlay(images[0], cam[0])
    assert blended.shape == images[0].shape
    assert blended.dtype == np.uint8

    path = tmp_path / f"{arch}.tflite"
    size = export_tflite(model, path, quantize="float16")
    assert size == path.stat().st_size > 0
    lite = tflite_probabilities(path, images[:6])
    keras = model.predict(images[:6].astype(np.float32), verbose=0).ravel()
    assert np.abs(lite - keras).max() < 0.01
    assert tflite_latency(path, images[0], threads=1, runs=3) > 0


def test_architecture_table_is_what_the_report_describes():
    assert ARCHITECTURES == {
        "mobilenet_v2": ("MobileNetV2", 0.35, 30),
        "mobilenet_v3_small": ("MobileNetV3Small", 0.75, 30),
    }
