"""export_milk_vectors de punta a punta con un COCO falso y pequeño (sin el dataset real)."""

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import export_milk_vectors as emv

MODEL = Path(__file__).resolve().parents[1] / "models" / "milk_cnn.tflite"
CATEGORIES = ["Normal Milk", "Blood tinged Milk", "Curd like Milk", "Watery Milk"]
# (nombre, grado): una foto de teléfono y un frame de video normales, y uno de cada grado anormal
PHOTOS = [
    ("PXL_20260526_032650588.jpg", "Normal Milk"),
    ("frame_0001.jpg", "Normal Milk"),
    ("frame_0002.jpg", "Blood tinged Milk"),
    ("frame_0003.jpg", "Curd like Milk"),
    ("PXL_20260526_040000000.jpg", "Watery Milk"),
]


def fake_coco(root: Path) -> Path:
    categories = [{"id": i, "name": name} for i, name in enumerate(CATEGORIES)]
    rng = np.random.default_rng(0)
    for split in ("train", "valid", "test"):
        (root / split).mkdir(parents=True)
        images, annotations = [], []
        if split == "train":
            for i, (name, grade) in enumerate(PHOTOS):
                pixels = rng.integers(0, 256, size=(90, 120, 3), dtype=np.uint8)
                file_name = f"img{i}.jpg"
                Image.fromarray(pixels).save(root / split / file_name, quality=95)
                images.append({"id": i, "file_name": file_name, "extra": {"name": name}})
                annotations.append(
                    {"id": i, "image_id": i, "category_id": CATEGORIES.index(grade), "bbox": [20, 10, 50, 40]}
                )
        coco = {"categories": categories, "images": images, "annotations": annotations}
        (root / split / "_annotations.coco.json").write_text(json.dumps(coco), encoding="utf-8")
    return root


def test_export_writes_fixtures_and_probabilities(tmp_path):
    vectors = emv.export(fake_coco(tmp_path / "coco"), MODEL, tmp_path / "fixtures")
    cases = vectors["cases"]
    assert [c["grade"] for c in cases] == [g for g, _ in emv.WANTED]
    assert [c["source"] for c in cases] == ["PXL", "video", "video", "video", "PXL"]
    for case in cases:
        assert 0.0 <= case["tflite"] <= 1.0
        assert case["box"] == [15, 6, 75, 54]  # caja (20, 10, 50, 40) + 10 % por lado
        crop = np.asarray(Image.open(tmp_path / "fixtures" / case["pythonCrop"]))
        assert crop.shape == (160, 160, 3)
        assert (tmp_path / "fixtures" / case["photo"]).exists()
    assert len(vectors["synthetic"]["cases"]) == len(emv.SYNTHETIC_BOXES)


def test_main_writes_config_and_vectors(tmp_path, monkeypatch, capsys):
    monkeypatch.setattr(emv, "CONFIG_PATH", tmp_path / "config.json")
    monkeypatch.setattr(emv, "VECTORS_PATH", tmp_path / "vectors.json")
    monkeypatch.setattr(emv, "FIXTURES_DIR", tmp_path / "fixtures")
    coco = fake_coco(tmp_path / "coco")
    monkeypatch.setattr(sys, "argv", ["export_milk_vectors.py", "--coco", str(coco), "--model", str(MODEL)])
    status = emv.main()
    assert status == 0
    config = json.loads((tmp_path / "config.json").read_text(encoding="utf-8"))
    assert config["disclaimer"] == emv.DISCLAIMER
    assert config["onlyDemoBuild"] is True
    assert len(json.loads((tmp_path / "vectors.json").read_text(encoding="utf-8"))["cases"]) == 5
    assert "case_1.jpg: Normal Milk (PXL)" in capsys.readouterr().out
