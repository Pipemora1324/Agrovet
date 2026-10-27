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
