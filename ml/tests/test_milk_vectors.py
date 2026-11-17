"""Modelo de leche de la pantalla experimental: archivos que usa la app y casos de verificación."""

import hashlib
import json
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

from export_milk_vectors import DISCLAIMER, WANTED, choose_cases, pixel_box, synthetic_photo
from milk_data import IMAGE_SIZE, MilkImage
from train_cnn import tflite_predict
from udder_public_data import udder_crop

ML_DIR = Path(__file__).resolve().parents[1]
MODELS = ML_DIR / "models"
FIXTURES = ML_DIR / "tests" / "fixtures" / "milk"
CONFIG = json.loads((MODELS / "milk_cnn_config.json").read_text(encoding="utf-8"))
VECTORS = json.loads((MODELS / "milk_cnn_vectors.json").read_text(encoding="utf-8"))


def test_config_is_experimental_and_matches_the_model_file():
    assert CONFIG["enabledByDefault"] is False
    assert CONFIG["onlyDemoBuild"] is True
    assert CONFIG["disclaimer"] == DISCLAIMER
    assert "No es diagnóstico" in CONFIG["disclaimer"]
    assert CONFIG["inputSize"] == IMAGE_SIZE == 160
    model = (MODELS / CONFIG["modelFile"]).read_bytes()
    assert hashlib.sha256(model).hexdigest() == CONFIG["sha256"]


def test_app_copies_are_identical_to_ml():
    app = ML_DIR.parent / "mobile" / "assets" / "model"
    assert (app / "milk_cnn.tflite").read_bytes() == (MODELS / "milk_cnn.tflite").read_bytes()
    assert _text(app / "milk_cnn_config.json") == _text(MODELS / "milk_cnn_config.json")


def _text(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def test_vectors_cover_both_classes_and_phone_photos():
    cases = VECTORS["cases"]
    assert len(cases) == len(WANTED) == 5
    assert {c["label"] for c in cases} == {0, 1}
    assert {c["source"] for c in cases} == {"PXL", "video"}
    assert "NO miden la exactitud" in VECTORS["description"]


@pytest.mark.parametrize("case", VECTORS["cases"], ids=lambda c: c["photo"])
def test_saved_crop_is_what_udder_crop_gives_for_the_box(case):
    with Image.open(FIXTURES / case["photo"]) as photo:
        photo.load()
        assert list(photo.size) == case["imageSize"]
        left, top, right, bottom = case["box"]
        # La caja guardada ya tiene el margen: recortarla sin margen da lo mismo que udder_crop
        crop = udder_crop(photo, (left, top, right - left, bottom - top), size=IMAGE_SIZE, margin=0.0)
    saved = np.asarray(Image.open(FIXTURES / case["pythonCrop"]).convert("RGB"))
    assert crop.shape == (IMAGE_SIZE, IMAGE_SIZE, 3)
    assert np.array_equal(crop, saved)


@pytest.mark.parametrize("case", VECTORS["synthetic"]["cases"], ids=lambda c: c["pythonCrop"])
def test_synthetic_crops_are_reproducible(case):
    photo = Image.fromarray(synthetic_photo(*VECTORS["synthetic"]["size"]))
    left, top, right, bottom = case["box"]
    crop = udder_crop(photo, (left, top, right - left, bottom - top), size=IMAGE_SIZE, margin=0.0)
    assert np.array_equal(crop, np.asarray(Image.open(FIXTURES / case["pythonCrop"]).convert("RGB")))


def test_tflite_probabilities_match_the_vectors():
    crops = np.stack(
        [np.asarray(Image.open(FIXTURES / c["pythonCrop"]).convert("RGB")) for c in VECTORS["cases"]]
    )
    out = tflite_predict(MODELS / CONFIG["modelFile"], crops)
    for case, value in zip(VECTORS["cases"], out):
        assert value == pytest.approx(case["tflite"], abs=1e-5)
        assert (value >= VECTORS["threshold"]) == (case["tflite"] >= VECTORS["threshold"])


def test_pixel_box_adds_the_margin_and_stays_inside_the_image():
    assert pixel_box((10.0, 20.0, 100.0, 50.0), 640, 360) == (0, 15, 120, 75)
    assert pixel_box((600.5, 300.2, 80.0, 80.0), 640, 360) == (592, 292, 640, 360)


def test_choose_cases_takes_one_well_per_request_from_different_images(tmp_path):
    box = (1.0, 1.0, 5.0, 5.0)
    images = [
        MilkImage("PXL_a.jpg", tmp_path / "a", "train", [("Normal Milk", (0, 0, 5, 5))]),
        MilkImage("frame_b.jpg", tmp_path / "b", "train", [("Normal Milk", box), ("Watery Milk", box)]),
        MilkImage("PXL_c.jpg", tmp_path / "c", "valid", [("Watery Milk", (2, 2, 5, 5))]),
    ]
    chosen = choose_cases(images, (("Normal Milk", "PXL"), ("Normal Milk", "video"), ("Watery Milk", None)))
    assert [(im.name, grade) for im, grade, _ in chosen] == [
        ("PXL_a.jpg", "Normal Milk"),
        ("frame_b.jpg", "Normal Milk"),
        ("PXL_c.jpg", "Watery Milk"),
    ]
    with pytest.raises(ValueError):
        choose_cases(images, (("Curd like Milk", None),))
