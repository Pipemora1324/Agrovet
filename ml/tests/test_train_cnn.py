import sys

from train_cnn import CLASSES, build_cnn, count_images, main


def test_model_has_frozen_backbone_and_binary_output():
    model, backbone = build_cnn(weights=None)
    assert model.input_shape == (None, 224, 224, 3)
    assert model.output_shape == (None, 1)
    assert backbone.trainable is False
    assert model.get_layer("mastitis_probability").activation.__name__ == "sigmoid"


def test_counts_only_images_per_class(tmp_path):
    (tmp_path / "healthy").mkdir()
    (tmp_path / "healthy" / "a.jpg").write_bytes(b"x")
    (tmp_path / "healthy" / "notas.txt").write_text("no es imagen")
    assert count_images(tmp_path) == {"healthy": 1, "mastitis": 0}
    assert set(CLASSES) == {"healthy", "mastitis"}


def test_without_real_images_it_does_not_train(tmp_path, monkeypatch, capsys):
    monkeypatch.setattr(sys, "argv", ["train_cnn.py", "--images", str(tmp_path)])
    assert main() == 0
    assert "sigue desactivada" in capsys.readouterr().out


def test_smoke_training_runs_end_to_end_without_scientific_value(tmp_path):
    """PRUEBA DE HUMO, SIN VALOR CIENTÍFICO: imágenes de ruido generadas aquí, solo para comprobar
    que el pipeline completo (carga, entrenamiento, ajuste fino y exportación a TFLite) funciona.
    Sus métricas no significan nada y no se guardan en reports/."""
    import numpy as np
    import tensorflow as tf

    from train_cnn import train

    rng = np.random.default_rng(0)
    for name in CLASSES:
        folder = tmp_path / "imagenes" / name
        folder.mkdir(parents=True)
        for i in range(5):
            pixels = rng.integers(0, 256, size=(64, 64, 3), dtype=np.uint8)
            (folder / f"{i}.jpg").write_bytes(tf.io.encode_jpeg(pixels).numpy())

    model_path = tmp_path / "salida" / "udder_cnn.keras"
    tflite_path = tmp_path / "salida" / "udder_cnn.tflite"
    metrics = train(tmp_path / "imagenes", epochs=1, fine_tune_epochs=1, model_path=model_path,
                    tflite_path=tflite_path, weights=None, batch_size=4)

    assert "val_auc" in metrics
    assert model_path.exists() and tflite_path.exists()
    interpreter = tf.lite.Interpreter(model_path=str(tflite_path))
    interpreter.allocate_tensors()
    image = rng.integers(0, 256, size=(1, 224, 224, 3)).astype(np.float32)
    interpreter.set_tensor(interpreter.get_input_details()[0]["index"], image)
    interpreter.invoke()
    probability = float(interpreter.get_tensor(interpreter.get_output_details()[0]["index"])[0][0])
    assert 0.0 <= probability <= 1.0
