"""Datos del clasificador de leche (pozo normal o anormal), sin TensorFlow.

Dataset: "Mastitis dataset" v3 de Roboflow Universe (abdurrehman4198), CC BY 4.0. 453 imágenes de
640 x 360 (frames de video y fotos de teléfono PXL_*) con una caja por pozo de la paleta: Normal,
Blood tinged, Watery y Curd like Milk. Los datos quedan fuera del repositorio.

Decisiones:
- Se ignoran los splits de Roboflow: frames casi idénticos del mismo video caen en train, valid y
  test (fuga).
- Grupos: se unen las imágenes casi idénticas (pHash y dHash cercanos) y las fotos PXL de la misma
  sesión (tomas separadas por menos de SESSION_GAP_MINUTES). Cada grupo va completo a un fold.
- Etiqueta binaria: 0 = Normal Milk, 1 = sangre, grumos o aguada.
"""

from __future__ import annotations

import io
import json
import re
from collections.abc import Callable, Sequence
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

from udder_public_data import CROP_MARGIN, _UnionFind, crop_box, hamming, pad_to_square, phash, udder_crop

SPLITS = ("train", "valid", "test")
NORMAL = "Normal Milk"
GRADES = ("Normal Milk", "Blood tinged Milk", "Curd like Milk", "Watery Milk")
IMAGE_SIZE = 160
PHASH_SAME = 8
DHASH_SAME = 12
SESSION_GAP_MINUTES = 10
# Para auditar etiquetas: imágenes casi iguales (frames contiguos) y cajas que se solapan
IDENTICAL_PHASH = 4
SAME_WELL_IOU = 0.5
PXL_PATTERN = re.compile(r"^PXL_(\d{8})_(\d{6})(\d{3})")


@dataclass
class MilkImage:
    name: str
    path: Path
    split: str
    boxes: list[tuple[str, tuple[float, float, float, float]]] = field(default_factory=list)

    @property
    def source(self) -> str:
        return "PXL" if self.name.startswith("PXL_") else "video"


def load_images(coco_dir: Path) -> list[MilkImage]:
    """Todas las imágenes de los tres splits de Roboflow con sus cajas (grado, (x, y, w, h))."""
    coco_dir = Path(coco_dir)
    images = []
    for split in SPLITS:
        data = json.loads((coco_dir / split / "_annotations.coco.json").read_text(encoding="utf-8"))
        categories = {c["id"]: c["name"] for c in data["categories"]}
        boxes: dict[int, list[tuple[str, tuple[float, float, float, float]]]] = {}
        for ann in data["annotations"]:
            grade = categories[ann["category_id"]]
            if grade not in GRADES:
                continue  # la supercategoría de Roboflow no se usa en ninguna caja
            x, y, w, h = (float(v) for v in ann["bbox"])
            boxes.setdefault(ann["image_id"], []).append((grade, (x, y, w, h)))
        for im in data["images"]:
            name = im.get("extra", {}).get("name", im["file_name"])
            images.append(MilkImage(name, coco_dir / split / im["file_name"], split, boxes.get(im["id"], [])))
    return images


def pxl_timestamp(name: str) -> datetime | None:
    """Hora de la toma según el nombre de los teléfonos Pixel: PXL_AAAAMMDD_HHMMSSmmm."""
    match = PXL_PATTERN.match(name)
    if not match:
        return None
    day, clock, millis = match.groups()
    return datetime.strptime(day + clock, "%Y%m%d%H%M%S").replace(microsecond=int(millis) * 1000)


def pxl_sessions(names: Sequence[str], gap_minutes: float = SESSION_GAP_MINUTES) -> list[int | None]:
    """Sesión de cada foto PXL (None para los frames de video): fotos ordenadas por hora y una sesión
    nueva cada vez que pasan más de gap_minutes entre dos tomas seguidas."""
    stamps = [pxl_timestamp(n) for n in names]
    order = sorted((s, i) for i, s in enumerate(stamps) if s is not None)
    sessions: list[int | None] = [None] * len(names)
    current, previous = -1, None
    for stamp, index in order:
        if previous is None or (stamp - previous).total_seconds() > gap_minutes * 60:
            current += 1
        sessions[index] = current
        previous = stamp
    return sessions


def dhash(image: Image.Image) -> np.ndarray:
    """dHash de 64 bits: compara cada píxel con su vecino de la derecha en una versión de 9 x 8."""
    gray = np.asarray(image.convert("L").resize((9, 8), Image.Resampling.LANCZOS), dtype=np.float64)
    return (gray[:, 1:] > gray[:, :-1]).ravel()


def group_images(
    pils: Sequence[Image.Image],
    sessions: Sequence[int | None],
    phash_same: int = PHASH_SAME,
    dhash_same: int = DHASH_SAME,
) -> list[int]:
    """Grupo de cada imagen (0..k-1): une casi duplicados (pHash Y dHash cercanos) y fotos PXL de la
    misma sesión. Dos frames de video sin parecido quedan en grupos distintos."""
    ph = [phash(p) for p in pils]
    dh = [dhash(p) for p in pils]
    uf = _UnionFind(len(pils))
    for i in range(len(pils)):
        for k in range(i + 1, len(pils)):
            if hamming(ph[i], ph[k]) <= phash_same and hamming(dh[i], dh[k]) <= dhash_same:
                uf.union(i, k)
    first_of_session: dict[int, int] = {}
    for i, session in enumerate(sessions):
        if session is not None:
            uf.union(first_of_session.setdefault(session, i), i)
    roots: dict[int, int] = {}
    return [roots.setdefault(uf.find(i), len(roots)) for i in range(len(pils))]


def context_only(
    image: Image.Image,
    bboxes: Sequence[tuple[float, float, float, float]],
    size: int = IMAGE_SIZE,
    margin: float = CROP_MARGIN,
) -> np.ndarray:
    """La foto completa con TODOS los pozos tapados en negro (caja + margen): solo quedan la paleta,
    el suelo, la mano y la luz. Mide cuánto 'predice' el contexto sin ver ninguna leche."""
    pixels = np.asarray(image.convert("RGB"), dtype=np.uint8).copy()
    for bbox in bboxes:
        x0, y0, x1, y1 = crop_box(bbox, image.width, image.height, margin)
        pixels[int(np.floor(y0)) : int(np.ceil(y1)), int(np.floor(x0)) : int(np.ceil(x1))] = 0
    square = pad_to_square(Image.fromarray(pixels)).resize((size, size), Image.Resampling.BILINEAR)
    return np.asarray(square, dtype=np.uint8)


def iou(a: tuple[float, float, float, float], b: tuple[float, float, float, float]) -> float:
    """Intersección sobre unión de dos cajas (x, y, w, h)."""
    ix = max(0.0, min(a[0] + a[2], b[0] + b[2]) - max(a[0], b[0]))
    iy = max(0.0, min(a[1] + a[3], b[1] + b[3]) - max(a[1], b[1]))
    inter = ix * iy
    union = a[2] * a[3] + b[2] * b[3] - inter
    return inter / union if union > 0 else 0.0


def label_conflicts(
    images: Sequence[MilkImage],
    pils: Sequence[Image.Image],
    max_phash: int = IDENTICAL_PHASH,
    min_iou: float = SAME_WELL_IOU,
) -> list[dict]:
    """Pares de imágenes casi iguales donde el mismo pozo (cajas solapadas) tiene grados distintos."""
    hashes = [phash(p) for p in pils]
    conflicts = []
    for i in range(len(images)):
        for k in range(i + 1, len(images)):
            if hamming(hashes[i], hashes[k]) <= max_phash:
                conflicts += _box_conflicts(images[i], images[k], min_iou)
    return conflicts


def _box_conflicts(a: MilkImage, b: MilkImage, min_iou: float) -> list[dict]:
    """Cajas de a y b que se solapan (el mismo pozo) con grados distintos."""
    return [
        {"a": a.name, "b": b.name, "grade_a": grade_a, "grade_b": grade_b}
        for grade_a, box_a in a.boxes
        for grade_b, box_b in b.boxes
        if grade_a != grade_b and iou(box_a, box_b) >= min_iou
    ]


@dataclass
class Wells:
    """Un elemento por pozo. crops: recorte (caja + 10 %, cuadrado); context: la foto sin leche."""

    crops: np.ndarray
    context: np.ndarray
    labels: np.ndarray
    groups: np.ndarray
    sources: np.ndarray
    grades: np.ndarray
    image_index: np.ndarray


def build_wells(
    images: Sequence[MilkImage], pils: Sequence[Image.Image], groups: Sequence[int], size: int = IMAGE_SIZE
) -> Wells:
    crops, context, labels, well_groups, sources, grades, index = [], [], [], [], [], [], []
    for i, (im, pil, group) in enumerate(zip(images, pils, groups)):
        if not im.boxes:
            continue
        background = context_only(pil, [box for _, box in im.boxes], size)
        for grade, box in im.boxes:
            crops.append(udder_crop(pil, box, size=size))
            context.append(background)
            labels.append(0 if grade == NORMAL else 1)
            well_groups.append(group)
            sources.append(im.source)
            grades.append(grade)
            index.append(i)
    return Wells(
        np.stack(crops),
        np.stack(context),
        np.array(labels),
        np.array(well_groups),
        np.array(sources),
        np.array(grades),
        np.array(index),
    )


# ---------------------------------------------------------------- degradaciones para robustez


def _to_image(array: np.ndarray) -> Image.Image:
    return Image.fromarray(np.asarray(array, dtype=np.uint8))


def brightness(array: np.ndarray, factor: float) -> np.ndarray:
    """Más o menos luz: multiplica la intensidad (1.0 = sin cambio)."""
    return np.asarray(ImageEnhance.Brightness(_to_image(array)).enhance(factor), dtype=np.uint8)


def blur(array: np.ndarray, radius: float) -> np.ndarray:
    """Desenfoque gaussiano de radio en píxeles (foto movida o fuera de foco)."""
    return np.asarray(_to_image(array).filter(ImageFilter.GaussianBlur(radius)), dtype=np.uint8)


def rotate(array: np.ndarray, degrees: float) -> np.ndarray:
    """Rotación con relleno negro, como el relleno del recorte."""
    return np.asarray(
        _to_image(array).rotate(degrees, resample=Image.Resampling.BILINEAR, fillcolor=(0, 0, 0)),
        dtype=np.uint8,
    )


def jpeg(array: np.ndarray, quality: int) -> np.ndarray:
    """Compresión JPEG con la calidad dada (las apps de mensajería suelen usar 50-80)."""
    buffer = io.BytesIO()
    _to_image(array).save(buffer, format="JPEG", quality=quality)
    return np.asarray(Image.open(io.BytesIO(buffer.getvalue())).convert("RGB"), dtype=np.uint8)


DEGRADATIONS: dict[str, tuple[Callable[[np.ndarray, float], np.ndarray], tuple[float, ...]]] = {
    "luz": (brightness, (0.5, 0.7, 1.3, 1.6)),
    "desenfoque": (blur, (1.0, 2.0, 4.0)),
    "rotacion": (rotate, (15.0, 45.0, 90.0, 180.0)),
    "jpeg": (lambda a, q: jpeg(a, int(q)), (60.0, 30.0, 10.0)),
}


def degrade(images: np.ndarray, kind: str, level: float) -> np.ndarray:
    function, _ = DEGRADATIONS[kind]
    return np.stack([function(image, level) for image in images])
