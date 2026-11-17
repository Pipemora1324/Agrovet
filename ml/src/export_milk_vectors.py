"""Casos para comprobar que la app prepara la foto de leche igual que ml/ (pantalla experimental).

El clasificador de pozo de leche (reports/milk_cnn.json) solo entra en el APK de demostración y
siempre como experimental: un solo dataset público, sin laboratorio. Este script toma 5 pozos del
dataset (uno por grado, más una foto de teléfono) y guarda para cada uno:

- la foto original en tests/fixtures/milk/ (CC BY 4.0, ver el README de esa carpeta),
- la caja de recorte en píxeles (caja + 10 %, como en el entrenamiento),
- el recorte de 160 px que produce Python (PNG, sin pérdida) para comparar píxel a píxel,
- la probabilidad que da el TFLite float16 sobre ese recorte.

    python src/export_milk_vectors.py --coco "C:/.../Data/roboflow_leche/Mastitis dataset.v3i.coco"
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

from milk_data import IMAGE_SIZE, NORMAL, load_images
from train_cnn import tflite_predict
from udder_public_data import CROP_MARGIN, crop_box, udder_crop

ML_DIR = Path(__file__).resolve().parents[1]
MODEL_PATH = ML_DIR / "models" / "milk_cnn.tflite"
CONFIG_PATH = ML_DIR / "models" / "milk_cnn_config.json"
VECTORS_PATH = ML_DIR / "models" / "milk_cnn_vectors.json"
FIXTURES_DIR = ML_DIR / "tests" / "fixtures" / "milk"
THRESHOLD = 0.5
DISCLAIMER = (
    "Experimental. No es diagnóstico. Solo validado con un conjunto de datos; con fotos nuevas puede fallar."
)
# (grado, origen) de cada caso; None = cualquier origen
WANTED = (
    (NORMAL, "PXL"),
    (NORMAL, "video"),
    ("Blood tinged Milk", None),
    ("Curd like Milk", None),
    ("Watery Milk", "PXL"),
)


def pixel_box(bbox, width, height, margin=CROP_MARGIN):
    """Caja (izquierda, arriba, derecha, abajo) en píxeles enteros, como la recorta udder_crop."""
    x0, y0, x1, y1 = crop_box(bbox, width, height, margin)
    return int(np.floor(x0)), int(np.floor(y0)), int(np.ceil(x1)), int(np.ceil(y1))


def choose_cases(images, wanted=WANTED):
    """Un pozo por cada (grado, origen) pedido, de imágenes distintas, en orden de nombre."""
    chosen, used = [], set()
    for grade, source in wanted:
        for image in sorted(images, key=lambda im: im.name):
            if image.name in used or (source is not None and image.source != source):
                continue
            box = next((b for g, b in image.boxes if g == grade), None)
            if box is not None:
                chosen.append((image, grade, box))
                used.add(image.name)
                break
        else:
            raise ValueError(f"No hay un pozo {grade} de origen {source}")
    return chosen


SYNTHETIC_SIZE = (257, 181)
# Cajas (izquierda, arriba, derecha, abajo): una que reduce (237 x 163 -> 160) y otra que amplía (100 x 60)
SYNTHETIC_BOXES = ((13, 7, 250, 170), (20, 30, 120, 90))


def synthetic_photo(width: int = SYNTHETIC_SIZE[0], height: int = SYNTHETIC_SIZE[1]) -> np.ndarray:
    """Imagen definida por fórmula, con mucho detalle, para comparar recorte y redimensionado sin JPEG.
    La app usa la misma fórmula."""
    y, x = np.mgrid[0:height, 0:width]
    channels = [(x * 7 + y * 3) % 256, (x * 5 + y * 11) % 256, (x * 13 + y * 2) % 256]
    return np.stack(channels, axis=-1).astype(np.uint8)


def synthetic_cases(fixtures_dir: Path) -> list[dict]:
    photo = Image.fromarray(synthetic_photo())
    cases = []
    for number, (left, top, right, bottom) in enumerate(SYNTHETIC_BOXES, start=1):
        crop = udder_crop(photo, (left, top, right - left, bottom - top), size=IMAGE_SIZE, margin=0.0)
        name = f"synthetic_{number}_crop{IMAGE_SIZE}.png"
        Image.fromarray(crop).save(fixtures_dir / name)
        cases.append({"box": [left, top, right, bottom], "pythonCrop": name})
    return cases


def model_config(model_path: Path) -> dict:
    return {
        "modelFile": model_path.name,
        "sha256": hashlib.sha256(model_path.read_bytes()).hexdigest(),
        "architecture": "MobileNetV2 alpha 0.35, TFLite float16",
        "inputSize": IMAGE_SIZE,
        "inputRange": "RGB 0-255 en float32; el modelo reescala a [-1, 1]",
        "crop": "un pozo: caja + 10 % por lado, centrada en un cuadrado con relleno negro (0, 0, 0), "
        "redimensionada a 160 x 160 con el bilineal de Pillow",
        "cropMargin": CROP_MARGIN,
        "threshold": THRESHOLD,
        "output": "probabilidad de leche de aspecto anormal (sangre, grumos o aguada)",
        "enabledByDefault": False,
        "onlyDemoBuild": True,
        "disclaimer": DISCLAIMER,
        "source": {
            "name": "Mastitis dataset v3 (Roboflow Universe, usuario abdurrehman4198)",
            "url": "https://universe.roboflow.com/abdurrehman4198-gmail-com/mastitis-dataset",
            "license": "CC BY 4.0",
            "labels": "del autor del dataset, sin laboratorio",
        },
    }


def export(coco_dir: Path, model_path: Path, fixtures_dir: Path) -> dict:
    fixtures_dir.mkdir(parents=True, exist_ok=True)
    cases, crops = [], []
    for number, (image, grade, bbox) in enumerate(choose_cases(load_images(coco_dir)), start=1):
        photo = f"case_{number}.jpg"
        shutil.copyfile(image.path, fixtures_dir / photo)
        with Image.open(image.path) as pil:
            pil.load()
            crop = udder_crop(pil, bbox, size=IMAGE_SIZE)
            width, height = pil.size
        crop_file = f"case_{number}_crop{IMAGE_SIZE}.png"
        Image.fromarray(crop).save(fixtures_dir / crop_file)
        crops.append(crop)
        cases.append({
            "photo": photo,
            "pythonCrop": crop_file,
            "datasetName": image.name,
            "source": image.source,
            "grade": grade,
            "label": 0 if grade == NORMAL else 1,
            "imageSize": [width, height],
            "box": list(pixel_box(bbox, width, height)),
        })
    probabilities = tflite_predict(model_path, np.stack(crops))
    for case, probability in zip(cases, probabilities):
        case["tflite"] = round(float(probability), 7)
    return {
        "description": "Fotos del dataset de leche (CC BY 4.0) con la caja del pozo, el recorte de 160 px "
        "de Python y la probabilidad del TFLite. La app debe dar el mismo recorte (diferencia media por "
        "píxel pequeña) y la misma decisión. Estos pozos estuvieron en el entrenamiento del modelo final: "
        "sirven para comparar el preprocesamiento, NO miden la exactitud.",
        "threshold": THRESHOLD,
        "cases": cases,
        "synthetic": {"size": list(SYNTHETIC_SIZE), "cases": synthetic_cases(fixtures_dir)},
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Exporta los casos de verificación del modelo de leche.")
    parser.add_argument("--coco", type=Path, required=True)
    parser.add_argument("--model", type=Path, default=MODEL_PATH)
    args = parser.parse_args()
    config = model_config(args.model)
    CONFIG_PATH.write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    vectors = export(args.coco, args.model, FIXTURES_DIR)
    VECTORS_PATH.write_text(json.dumps(vectors, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for case in vectors["cases"]:
        print(f"{case['photo']}: {case['grade']} ({case['source']}) -> {case['tflite']:.4f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
