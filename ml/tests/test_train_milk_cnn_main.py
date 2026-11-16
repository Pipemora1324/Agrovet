"""Corrida completa de train_milk_cnn.main() con un COCO sintético diminuto y sin pesos de ImageNet:
validación cruzada de las dos redes, control de contexto, sesión PXL fuera, Grad-CAM, robustez,
calibración y exportación. Comprueba que el pipeline produce un informe completo; no mide calidad."""

import json
import sys

import numpy as np
import pytest
from PIL import Image

import train_milk_cnn

GRADES = ["Normal Milk", "Blood tinged Milk", "Watery Milk", "Curd like Milk"]


def write_coco(root):
    """28 imágenes distintas (24 frames de video y 4 fotos PXL de una misma sesión), cada una con un
    pozo normal y uno anormal, repartidas en los tres splits como en Roboflow."""
    names = [f"frame_{i:04d}.jpg" for i in range(24)] + [f"PXL_20260526_0326{i:02d}000.jpg" for i in range(4)]
    for s, split in enumerate(("train", "valid", "test")):
        folder = root / split
        folder.mkdir(parents=True)
        data = {
            "categories": [{"id": k, "name": g} for k, g in enumerate(GRADES)],
            "images": [],
            "annotations": [],
        }
        for i, name in enumerate(names):
            if i % 3 != s:
                continue
            rng = np.random.default_rng(i)
            # Un patrón grueso distinto por imagen (así el pHash no las confunde) más ruido fino
            coarse = Image.fromarray(rng.integers(0, 255, (3, 4, 3), dtype=np.uint8)).resize((96, 60))
            noise = rng.integers(-20, 20, (60, 96, 3))
            pixels = np.clip(np.asarray(coarse, dtype=int) + noise, 0, 255).astype(np.uint8)
            pixels[5:35, 50:80] = np.clip(
                pixels[5:35, 50:80].astype(int) + 90, 0, 255
            )  # pozo anormal, más claro
            Image.fromarray(pixels).save(folder / f"{i}.jpg")
            data["images"].append(
                {"id": i, "file_name": f"{i}.jpg", "width": 96, "height": 60, "extra": {"name": name}}
            )
            data["annotations"] += [
                {"id": 2 * i, "image_id": i, "category_id": 0, "bbox": [5, 5, 30, 30]},
                {"id": 2 * i + 1, "image_id": i, "category_id": 1 + i % 3, "bbox": [50, 5, 30, 30]},
            ]
        (folder / "_annotations.coco.json").write_text(json.dumps(data), encoding="utf-8")


@pytest.mark.filterwarnings("ignore")
def test_main_writes_a_complete_report(tmp_path, monkeypatch):
    ml_dir = tmp_path / "repo" / "ml"
    monkeypatch.setattr(train_milk_cnn, "ML_DIR", ml_dir)
    monkeypatch.setattr(train_milk_cnn, "FIGURES_DIR", ml_dir / "informes")
    monkeypatch.setattr(train_milk_cnn, "REPORT_PATH", ml_dir / "reports" / "milk_cnn.json")
    (ml_dir / "reports").mkdir(parents=True)
    write_coco(tmp_path / "coco")
    work = tmp_path / "work"
    args = [
        "train_milk_cnn.py",
        "--coco",
        str(tmp_path / "coco"),
        "--work-dir",
        str(work),
        "--splits",
        "2",
        "--repeats",
        "1",
        "--size",
        "32",
        "--head-epochs",
        "2",
        "--tune-epochs",
        "1",
        "--n-boot",
        "20",
        "--weights",
        "none",
        "--archs",
        "mobilenet_v2",
    ]
    monkeypatch.setattr(sys, "argv", args)

    assert train_milk_cnn.main() == 0

    report = json.loads((ml_dir / "reports" / "milk_cnn.json").read_text(encoding="utf-8"))
    assert report["dataset"]["images"] == 28
    assert report["dataset"]["wells"] == 56
    assert report["dataset"]["wells_by_source"] == {"PXL": 8, "video": 48}
    # Las 4 fotos PXL son una sola sesión: a lo sumo 24 frames + 1 grupo PXL
    assert 15 <= report["dataset"]["groups"] <= 25
    assert set(report["cv"]) == {"mobilenet_v2"}
    for cv in [*report["cv"].values(), report["context_only_control"]]:
        assert 0 <= cv["auc"] <= 1
        assert "ece" in cv
        assert sum(d["n"] for d in cv["confusion_by_grade"].values()) == 56
    # Los 8 pozos PXL más los de cualquier frame que el pHash haya unido a esa sesión
    assert report["leave_pxl_session_out"]["test_wells"] >= 8
    assert report["comparison_auc_difference"] is None  # con una sola red no hay comparación
    rows = report["robustness_rep0"]["mobilenet_v2"]
    assert rows[0]["degradation"] == "ninguna"
    assert len(rows) == 1 + 4 + 3 + 4 + 3
    assert report["export"]["keras_vs_tflite"]["wells"] == 56
    assert report["export"]["keras_vs_tflite"]["max_abs_diff"] < 0.01
    for path in [report["figures"]["calibration"], *report["gradcam"]["mobilenet_v2"]["figures"].values()]:
        assert (ml_dir / path).exists()
    # Avance por fold y modelos de la repetición 0 fuera del repositorio
    assert (work / "mobilenet_v2.json").exists()
    assert (work / "mobilenet_v2_fold0.keras").exists()
    assert len(list(work.glob("milk_*_float16.tflite"))) == 1

    # Si se vuelve a correr, retoma: los folds hechos no se repiten
    state = json.loads((work / "mobilenet_v2.json").read_text(encoding="utf-8"))
    assert sorted(state["done"]) == ["0-0", "0-1"]


def test_data_and_outputs_must_stay_outside_the_repository(tmp_path, monkeypatch):
    monkeypatch.setattr(train_milk_cnn, "ML_DIR", tmp_path / "ml")
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "train_milk_cnn.py",
            "--coco",
            str(tmp_path / "coco"),
            "--work-dir",
            str(tmp_path / "ml" / "trabajo"),
        ],
    )
    with pytest.raises(SystemExit, match="fuera del repositorio"):
        train_milk_cnn.main()
