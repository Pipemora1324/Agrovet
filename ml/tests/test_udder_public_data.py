import json

import numpy as np
import pytest
from PIL import Image

from udder_public_data import (IMAGE_SIZE, MIN_CROP_SIDE, assign_groups, background_only, crop_box,
                               load_dataset, load_records, pad_to_square, polygon_bbox, series_of,
                               short_side, udder_crop)

RED = (220, 30, 30)


def _image_with_box(bbox, size=432, color=RED, background=(40, 160, 40)):
    image = Image.new("RGB", (size, size), background)
    x, y, w, h = bbox
    pixels = np.asarray(image).copy()
    pixels[int(y):int(y + h), int(x):int(x + w)] = color
    return Image.fromarray(pixels)


def test_polygon_bbox_encloses_all_points():
    assert polygon_bbox([[10, 20, 50, 20, 30, 80]]) == (10.0, 20.0, 40.0, 60.0)


def test_crop_box_adds_ten_percent_margin_per_side():
    assert crop_box((100, 50, 100, 200), 432, 432) == pytest.approx((90, 30, 210, 270))


def test_crop_box_never_leaves_the_image():
    assert crop_box((5, 400, 100, 30), 432, 432) == pytest.approx((0, 397, 115, 432))


def test_crop_is_square_224_and_keeps_the_aspect_ratio():
    # Caja 100x200 -> recorte 120x240 -> se rellena a 240x240 con dos franjas negras de 60 px
    image = _image_with_box((100, 50, 100, 200))
    crop = udder_crop(image, (100, 50, 100, 200))
    assert crop.shape == (IMAGE_SIZE, IMAGE_SIZE, 3) and crop.dtype == np.uint8
    band = round(60 * IMAGE_SIZE / 240)
    assert crop[:, : band - 2].max() == 0 and crop[:, -(band - 2):].max() == 0   # relleno negro
    assert tuple(crop[112, 112]) == pytest.approx(RED, abs=2)                    # la ubre, sin deformar
    assert crop[112, band + 4][1] > 100                                          # el margen es fondo


def test_pad_to_square_centers_the_image():
    padded = pad_to_square(Image.new("RGB", (10, 4), (255, 255, 255)))
    pixels = np.asarray(padded)
    assert padded.size == (10, 10)
    assert pixels[:3].max() == 0 and pixels[3:7].min() == 255 and pixels[7:].max() == 0


def test_background_only_hides_the_udder_and_keeps_the_rest():
    image = _image_with_box((100, 100, 100, 100))
    hidden = background_only(image, (100, 100, 100, 100))
    assert hidden.shape == (IMAGE_SIZE, IMAGE_SIZE, 3)
    # el centro de la caja queda negro, sin rastro del rojo
    center = int(150 * IMAGE_SIZE / 432)
    assert hidden[center, center].max() == 0
    assert (hidden[..., 0] > 150).sum() == 0
    # el fondo verde sigue visible
    assert hidden[5, 5][1] > 100


def test_series_from_the_original_name():
    assert series_of("img-25-.jpg") == "img-N"
    assert series_of("img-44-Copy-2-Copy-Copy.jpg") == "img-N"
    assert series_of("13.jpg") == "N"
    assert series_of("IMG_2742-Copy-2-Copy.jpg") == "otro"


def _write_coco(folder, entries):
    """entries: (nombre, clase, bbox). Escribe imágenes y un COCO mínimo en folder/train."""
    split = folder / "train"
    split.mkdir(parents=True)
    categories = [{"id": i, "name": n} for i, n in enumerate(
        ["Udder", "Mastitis-High", "Mastitis-Low", "Mastitis-Moderate", "Mastitis-No"])]
    cat_id = {c["name"]: c["id"] for c in categories}
    images, annotations = [], []
    rng = np.random.default_rng(1)
    for i, (name, grade, bbox) in enumerate(entries):
        file_name = name.replace(".jpg", f"_jpg.rf.{i:032x}.jpg")
        pixels = rng.integers(0, 256, size=(432, 432, 3), dtype=np.uint8)
        Image.fromarray(pixels).save(split / file_name, quality=95)
        images.append({"id": i, "file_name": file_name, "width": 432, "height": 432, "extra": {"name": name}})
        x, y, w, h = bbox
        annotations.append({"id": i, "image_id": i, "category_id": cat_id[grade], "bbox": list(bbox),
                            "area": w * h, "segmentation": [[x, y, x + w, y, x + w, y + h, x, y + h]]})
    (split / "_annotations.coco.json").write_text(json.dumps(
        {"categories": categories, "images": images, "annotations": annotations}), encoding="utf-8")
    return folder


def test_load_records_binarizes_the_four_grades(tmp_path):
    coco = _write_coco(tmp_path, [("img-1-.jpg", "Mastitis-No", (50, 50, 200, 200)),
                                  ("img-9-.jpg", "Mastitis-Low", (50, 50, 200, 200)),
                                  ("2.jpg", "Mastitis-Moderate", (50, 50, 200, 200)),
                                  ("3.jpg", "Mastitis-High", (50, 50, 200, 200))])
    records = load_records(coco)
    assert [(r.name, r.label) for r in records] == [
        ("img-1-.jpg", 0), ("img-9-.jpg", 1), ("2.jpg", 1), ("3.jpg", 1)]


def test_small_udders_are_dropped(tmp_path):
    # 80 px + 10 % por lado = 96 px (se queda); 70 px + margen = 84 px (< 96, se descarta)
    coco = _write_coco(tmp_path, [("img-1-.jpg", "Mastitis-No", (100, 100, 80, 200)),
                                  ("img-5-.jpg", "Mastitis-Low", (100, 100, 70, 200)),
                                  ("img-9-.jpg", "Mastitis-High", (10, 10, 300, 300))])
    kept, crops, backgrounds, dropped = load_dataset(coco)
    assert [r.name for r in dropped] == ["img-5-.jpg"]
    assert [r.name for r in kept] == ["img-1-.jpg", "img-9-.jpg"]
    assert crops.shape == backgrounds.shape == (2, IMAGE_SIZE, IMAGE_SIZE, 3)
    assert all(short_side(crop_box(r.bbox, 432, 432)) >= MIN_CROP_SIDE for r in kept)


def test_duplicates_and_manual_pairs_share_a_group(tmp_path):
    coco = _write_coco(tmp_path, [("img-1-.jpg", "Mastitis-No", (50, 50, 200, 200)),
                                  ("img-20-.jpg", "Mastitis-No", (50, 50, 200, 200)),
                                  ("img-40-.jpg", "Mastitis-Low", (50, 50, 200, 200)),
                                  ("img-60-.jpg", "Mastitis-High", (50, 50, 200, 200))])
    records = load_records(coco)
    images = [Image.open(r.path).convert("RGB") for r in records]
    images[1] = images[0].copy()                                   # copia exacta de img-1
    assign_groups(records, images, manual=(("img-40-.jpg", "img-60-.jpg"),))
    group = {r.name: r.group for r in records}
    assert group["img-1-.jpg"] == group["img-20-.jpg"]
    assert group["img-40-.jpg"] == group["img-60-.jpg"]
    assert group["img-1-.jpg"] != group["img-40-.jpg"]
