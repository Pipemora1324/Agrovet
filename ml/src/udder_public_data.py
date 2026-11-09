"""Carga y prepara el dataset público de ubres de Roboflow para la CNN de triaje visual.

Dataset: "Mastitis" v1 (Roboflow Universe, espacio "yield-a2yrd", proyecto "mastitis-zmser"),
licencia CC BY 4.0. Formato COCO Segmentation, 124 fotos de 432x432 con un polígono por ubre y
clases Mastitis-No / Low / Moderate / High. Ver docs/datasets_publicos.md.

Los datos NO están en el repositorio: se pasa la carpeta del export COCO (la que contiene train/).
Cambios que se aplican (CC BY 4.0 pide indicarlos):
  - etiqueta binaria: sana = Mastitis-No; mastitis = Low + Moderate + High;
  - recorte de la ubre: caja del polígono más grande + 10 % de margen, relleno a cuadrado y 224 px;
  - se descartan los recortes con lado corto < 96 px;
  - grupos de la misma vaca (hash perceptual + revisión manual) para que no haya fuga entre folds.
"""

import json
import re
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
from PIL import Image

IMAGE_SIZE = 224
CROP_MARGIN = 0.10
MIN_CROP_SIDE = 96
HEALTHY_CLASS = "Mastitis-No"
PAD_VALUE = 0  # relleno negro; la app debe rellenar igual

# Pares que la revisión manual de las 124 fotos (2026-11-09) identificó como la misma vaca o escena
# y que el hash perceptual no unió. Unir de más solo quita imágenes de la evaluación independiente;
# unir de menos deja fuga entre folds.
MANUAL_SAME_ANIMAL = (
    ("11.jpg", "9.jpg"),            # mismas venas que 9 y 10, otro encuadre
    ("img-24-.jpg", "img-41-.jpg"),
    ("img-40-.jpg", "img-41-.jpg"),
    ("img-32-.jpg", "img-33-.jpg"),
    ("img-45-.jpg", "img-46-.jpg"),
    ("img-66-.jpg", "img-70-.jpg"),
    ("img-81-.jpg", "img-82-.jpg"),
    ("img-88-.jpg", "img-91-.jpg"),
    ("img-99-.jpg", "img-100-.jpg"),
    ("img-105-.jpg", "img-107-.jpg"),  # Moderate frente a No en la misma ubre
    ("img-108-.jpg", "img-109-.jpg"),
    ("img-109-.jpg", "img-111-.jpg"),
    ("img-125-.jpg", "img-128-.jpg"),
    ("img-129-.jpg", "img-130-.jpg"),
    ("img-142-.jpg", "img-144-.jpg"),
    ("img-144-.jpg", "img-145-.jpg"),
    ("img-156-.jpg", "img-158-.jpg"),
    ("img-161-.jpg", "img-162-.jpg"),
    ("img-164-.jpg", "img-165-.jpg"),
    ("img-165-.jpg", "img-166-.jpg"),
    ("img-166-.jpg", "img-167-.jpg"),
    ("img-171-.jpg", "img-172-.jpg"),
)
# Umbrales del agrupamiento automático (distancia de Hamming sobre 64 bits)
PHASH_SAME = 12
HIST_SAME = 0.35
CONSECUTIVE_GAP = 2


@dataclass
class UdderRecord:
    name: str            # nombre original de la foto (extra.name del COCO)
    path: Path
    grade: str           # clase original
    label: int           # 0 sana, 1 mastitis
    bbox: tuple          # caja (x, y, w, h) del polígono más grande
    width: int
    height: int
    series: str = field(default="")
    group: int = field(default=-1)


def series_of(name):
    """Origen aparente de la foto según el nombre: 'img-N' (mismo establo), 'N' (potrero/banco de
    imágenes) u 'otro'."""
    if name.startswith("img-"):
        return "img-N"
    if re.fullmatch(r"\d+\.jpg", name):
        return "N"
    return "otro"


def polygon_bbox(segmentation):
    """Caja (x, y, w, h) que encierra todos los puntos de un polígono COCO."""
    points = np.array([c for poly in segmentation for c in poly], dtype=float).reshape(-1, 2)
    x0, y0 = points.min(axis=0)
    x1, y1 = points.max(axis=0)
    return float(x0), float(y0), float(x1 - x0), float(y1 - y0)


def load_records(coco_dir):
    """Una entrada por foto con su polígono más grande y la etiqueta binaria."""
    coco_dir = Path(coco_dir)
    split_dir = coco_dir / "train" if (coco_dir / "train").exists() else coco_dir
    data = json.loads((split_dir / "_annotations.coco.json").read_text(encoding="utf-8"))
    categories = {c["id"]: c["name"] for c in data["categories"]}
    by_image = {}
    for ann in data["annotations"]:
        by_image.setdefault(ann["image_id"], []).append(ann)
    records = []
    for image in data["images"]:
        anns = by_image.get(image["id"], [])
        if not anns:
            continue
        main = max(anns, key=lambda a: a["area"])
        grade = categories[main["category_id"]]
        seg = main.get("segmentation")
        bbox = polygon_bbox(seg) if seg else tuple(float(v) for v in main["bbox"])
        name = image.get("extra", {}).get("name", image["file_name"])
        records.append(UdderRecord(name=name, path=split_dir / image["file_name"], grade=grade,
                                   label=0 if grade == HEALTHY_CLASS else 1, bbox=bbox,
                                   width=image["width"], height=image["height"], series=series_of(name)))
    return records


def crop_box(bbox, width, height, margin=CROP_MARGIN):
    """Caja de recorte (x0, y0, x1, y1): la caja del polígono más un margen por lado, sin salir de la
    imagen."""
    x, y, w, h = bbox
    x0 = max(0.0, x - margin * w)
    y0 = max(0.0, y - margin * h)
    x1 = min(float(width), x + w + margin * w)
    y1 = min(float(height), y + h + margin * h)
    return x0, y0, x1, y1


def short_side(box):
    x0, y0, x1, y1 = box
    return min(x1 - x0, y1 - y0)


def pad_to_square(image, fill=PAD_VALUE):
    """Centra la imagen en un cuadrado del lado mayor, sin deformarla."""
    w, h = image.size
    side = max(w, h)
    canvas = Image.new("RGB", (side, side), (fill, fill, fill))
    canvas.paste(image, ((side - w) // 2, (side - h) // 2))
    return canvas


def udder_crop(image, bbox, size=IMAGE_SIZE, margin=CROP_MARGIN):
    """Recorte de la ubre listo para la red: uint8 (size, size, 3)."""
    box = crop_box(bbox, image.width, image.height, margin)
    left, top = int(np.floor(box[0])), int(np.floor(box[1]))
    right, bottom = int(np.ceil(box[2])), int(np.ceil(box[3]))
    crop = image.convert("RGB").crop((left, top, right, bottom))
    square = pad_to_square(crop).resize((size, size), Image.BILINEAR)
    return np.asarray(square, dtype=np.uint8)


def background_only(image, bbox, size=IMAGE_SIZE, margin=CROP_MARGIN):
    """La foto completa con la zona de la ubre (caja + margen) tapada en negro: solo queda el fondo.
    Sirve para medir cuánto 'predice' el entorno sin ver la ubre."""
    img = image.convert("RGB").copy()
    box = crop_box(bbox, img.width, img.height, margin)
    pixels = np.asarray(img, dtype=np.uint8).copy()
    left, top = int(np.floor(box[0])), int(np.floor(box[1]))
    right, bottom = int(np.ceil(box[2])), int(np.ceil(box[3]))
    pixels[top:bottom, left:right] = PAD_VALUE
    square = pad_to_square(Image.fromarray(pixels)).resize((size, size), Image.BILINEAR)
    return np.asarray(square, dtype=np.uint8)


# ---------------------------------------------------------------- hash perceptual y grupos


def _dct_matrix(n):
    k = np.arange(n)
    m = np.cos(np.pi * (2 * k[None, :] + 1) * k[:, None] / (2 * n))
    m[0] *= 1 / np.sqrt(2)
    return m * np.sqrt(2 / n)


_DCT32 = _dct_matrix(32)


def phash(image):
    """pHash de 64 bits (DCT 32x32, bloque 8x8 de baja frecuencia) como vector booleano."""
    gray = np.asarray(image.convert("L").resize((32, 32), Image.LANCZOS), dtype=float)
    coeffs = (_DCT32 @ gray @ _DCT32.T)[:8, :8].ravel()
    return coeffs > np.median(coeffs[1:])


def hamming(a, b):
    return int(np.count_nonzero(a != b))


def color_histogram(image):
    hsv = np.asarray(image.convert("HSV").resize((64, 64)), dtype=float)
    hist = np.concatenate([np.histogram(hsv[..., c], bins=16, range=(0, 256))[0] for c in range(3)])
    return hist / hist.sum()


def _number(name):
    match = re.match(r"img-(\d+)-", name)
    return int(match.group(1)) if match else None


class _UnionFind:
    def __init__(self, n):
        self.parent = list(range(n))

    def find(self, x):
        while self.parent[x] != x:
            self.parent[x] = self.parent[self.parent[x]]
            x = self.parent[x]
        return x

    def union(self, a, b):
        self.parent[self.find(a)] = self.find(b)


def assign_groups(records, images, manual=MANUAL_SAME_ANIMAL):
    """Asigna record.group: fotos de la misma vaca o escena comparten grupo.

    Une dos fotos si (a) el pHash de la foto completa o del recorte de la ubre (también reflejado)
    está a <= PHASH_SAME bits, (b) son de la serie img-N con números a <= CONSECUTIVE_GAP y colores
    parecidos, o (c) la revisión manual las marcó como la misma vaca. Devuelve los pares unidos por
    regla para el informe."""
    n = len(records)
    full = [phash(img) for img in images]
    crops = []
    for rec, img in zip(records, images):
        crop = Image.fromarray(udder_crop(img, rec.bbox))
        crops.append((phash(crop), phash(crop.transpose(Image.FLIP_LEFT_RIGHT))))
    hists = [color_histogram(img) for img in images]
    uf = _UnionFind(n)
    reasons = []
    for i in range(n):
        for k in range(i + 1, n):
            d_full = hamming(full[i], full[k])
            d_crop = min(hamming(crops[i][0], crops[k][0]), hamming(crops[i][0], crops[k][1]))
            if d_full <= PHASH_SAME or d_crop <= PHASH_SAME:
                uf.union(i, k)
                reasons.append((records[i].name, records[k].name, "phash"))
                continue
            ni, nk = _number(records[i].name), _number(records[k].name)
            if ni is not None and nk is not None and abs(ni - nk) <= CONSECUTIVE_GAP:
                if float(np.abs(hists[i] - hists[k]).sum()) < HIST_SAME:
                    uf.union(i, k)
                    reasons.append((records[i].name, records[k].name, "consecutivas"))
    index = {rec.name: i for i, rec in enumerate(records)}
    for a, b in manual:
        if a in index and b in index:
            uf.union(index[a], index[b])
            reasons.append((a, b, "manual"))
    roots = {}
    for i, rec in enumerate(records):
        rec.group = roots.setdefault(uf.find(i), len(roots))
    return reasons


def load_dataset(coco_dir, min_side=MIN_CROP_SIDE):
    """Registros utilizables con sus recortes, fondos y grupos.

    Los grupos se calculan con las 124 fotos (antes de filtrar) para que una foto descartada no
    rompa la unión entre dos que sí quedan. Devuelve (registros, recortes, fondos, descartados)."""
    records = load_records(coco_dir)
    images = [Image.open(rec.path).convert("RGB") for rec in records]
    assign_groups(records, images)
    kept, crops, backgrounds, dropped = [], [], [], []
    for rec, img in zip(records, images):
        if short_side(crop_box(rec.bbox, img.width, img.height)) < min_side:
            dropped.append(rec)
            continue
        kept.append(rec)
        crops.append(udder_crop(img, rec.bbox))
        backgrounds.append(background_only(img, rec.bbox))
    return kept, np.stack(crops), np.stack(backgrounds), dropped
