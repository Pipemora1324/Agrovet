"""Datos del clasificador de leche: lectura del COCO, sesiones PXL, grupos sin fuga, recortes, contexto
sin leche, auditoría de etiquetas y degradaciones. Todo con imágenes sintéticas."""

import json
from datetime import datetime

import numpy as np
import pytest
from PIL import Image

from cnn_evaluation import repeated_group_folds
from milk_data import (
    DEGRADATIONS,
    NORMAL,
    MilkImage,
    blur,
    brightness,
    build_wells,
    context_only,
    degrade,
    dhash,
    group_images,
    iou,
    jpeg,
    label_conflicts,
    load_images,
    pxl_sessions,
    pxl_timestamp,
    rotate,
)


def write_split(folder, images):
    """images: lista de (nombre, [(grado, bbox)]). Las fotos son ruido de 64 x 36 con semilla fija."""
    folder.mkdir(parents=True)
    categories = [
        {"id": 0, "name": "milk"},
        {"id": 1, "name": "Normal Milk"},
        {"id": 2, "name": "Blood tinged Milk"},
    ]
    by_name = {c["name"]: c["id"] for c in categories}
    data = {"categories": categories, "images": [], "annotations": []}
    for i, (name, boxes) in enumerate(images):
        file_name = f"{i}_{name}"
        Image.fromarray(np.random.default_rng(i).integers(0, 255, (36, 64, 3), dtype=np.uint8)).save(
            folder / file_name
        )
        data["images"].append(
            {"id": i, "file_name": file_name, "width": 64, "height": 36, "extra": {"name": name}}
        )
        for grade, bbox in boxes:
            data["annotations"].append(
                {
                    "id": len(data["annotations"]),
                    "image_id": i,
                    "category_id": by_name[grade],
                    "bbox": list(bbox),
                }
            )
    (folder / "_annotations.coco.json").write_text(json.dumps(data), encoding="utf-8")


def test_load_images_reads_the_three_splits_and_ignores_unknown_categories(tmp_path):
    write_split(tmp_path / "train", [("frame_0001.jpg", [("Normal Milk", (1, 1, 20, 20))])])
    write_split(
        tmp_path / "valid",
        [
            (
                "PXL_20260526_032650588-MP.jpg",
                [("Blood tinged Milk", (5, 5, 10, 10)), ("Normal Milk", (30, 5, 10, 10))],
            )
        ],
    )
    write_split(tmp_path / "test", [("frame_0002.jpg", [])])
    data = json.loads((tmp_path / "test" / "_annotations.coco.json").read_text(encoding="utf-8"))
    data["annotations"].append({"id": 9, "image_id": 0, "category_id": 0, "bbox": [0, 0, 5, 5]})
    (tmp_path / "test" / "_annotations.coco.json").write_text(json.dumps(data), encoding="utf-8")

    images = load_images(tmp_path)

    assert [im.split for im in images] == ["train", "valid", "test"]
    assert [im.source for im in images] == ["video", "PXL", "video"]
    assert images[1].boxes == [
        ("Blood tinged Milk", (5.0, 5.0, 10.0, 10.0)),
        ("Normal Milk", (30.0, 5.0, 10.0, 10.0)),
    ]
    assert images[2].boxes == []
    assert images[0].path.exists()


def test_pxl_timestamp_parses_pixel_names():
    assert pxl_timestamp("PXL_20260526_032650588-MP.jpg") == datetime(2026, 5, 26, 3, 26, 50, 588000)
    assert pxl_timestamp("PXL_20260526_040823826.jpg") == datetime(2026, 5, 26, 4, 8, 23, 826000)
    assert pxl_timestamp("frame_0001.jpg") is None


def test_pxl_sessions_split_on_gaps_longer_than_the_limit():
    names = [
        "PXL_20260526_040000000.jpg",
        "frame_1.jpg",
        "PXL_20260526_030000000.jpg",
        "PXL_20260526_030900000.jpg",
        "PXL_20260526_031000000.jpg",
    ]
    # 03:00 -> 03:09 -> 03:10 es una sesión (saltos de 9 y 1 min); 04:00 es otra (50 min después)
    assert pxl_sessions(names) == [1, None, 0, 0, 0]
    assert pxl_sessions(names, gap_minutes=5) == [2, None, 0, 1, 1]
    assert pxl_sessions(["PXL_20260526_030000000.jpg", "PXL_20260526_031000000.jpg"], gap_minutes=10) == [
        0,
        0,
    ]


def noise(seed, size=(48, 64)):
    return Image.fromarray(np.random.default_rng(seed).integers(0, 255, (*size, 3), dtype=np.uint8))


def test_near_duplicates_and_sessions_share_a_group():
    base = noise(0)
    almost = Image.fromarray(np.clip(np.asarray(base, dtype=int) + 3, 0, 255).astype(np.uint8))
    pils = [base, almost, noise(1), noise(2), noise(3)]
    # 0 y 1 casi iguales; 3 y 4 distintas pero de la misma sesión PXL; 2 sola
    groups = group_images(pils, [None, None, None, 7, 7])

    assert groups[0] == groups[1]
    assert groups[3] == groups[4]
    assert len({groups[0], groups[2], groups[3]}) == 3
    assert sorted(set(groups)) == [0, 1, 2]


def test_dhash_is_64_bits_and_ignores_uniform_brightness():
    image = noise(4)
    brighter = Image.fromarray(np.clip(np.asarray(image, dtype=int) + 20, 0, 255).astype(np.uint8))
    assert dhash(image).shape == (64,)
    assert np.count_nonzero(dhash(image) != dhash(brighter)) <= 4


def test_folds_never_split_a_group():
    labels = np.array([0, 1] * 20)
    groups = np.repeat(np.arange(10), 4)
    for _, _, train_idx, test_idx in repeated_group_folds(labels, groups, n_splits=5, n_repeats=2):
        assert not set(groups[train_idx]) & set(groups[test_idx])


def test_context_only_blacks_out_every_well_with_its_margin():
    image = Image.new("RGB", (100, 50), (200, 200, 200))
    out = context_only(image, [(10, 10, 20, 20), (60, 10, 20, 20)], size=100, margin=0.1)
    # Cuadrado 100 x 100 con la foto centrada (filas 25-74); cajas + 10 % tapadas
    assert out.shape == (100, 100, 3)
    assert out.dtype == np.uint8
    assert (out[25 + 20, 20] == 0).all()
    assert (out[25 + 20, 70] == 0).all()
    assert (out[25 + 20, 45] == 200).all()  # entre los dos pozos queda el fondo
    assert (out[25 + 9, 9] == 0).all()  # el margen también se tapa
    assert (out[25 + 40, 95] == 200).all()


def test_build_wells_one_entry_per_box_with_labels_and_groups():
    images = [
        MilkImage("frame_1.jpg", None, "train", [(NORMAL, (2, 2, 20, 20)), ("Watery Milk", (30, 2, 20, 20))]),
        MilkImage("PXL_20260526_030000000.jpg", None, "test", [("Curd like Milk", (5, 5, 30, 30))]),
        MilkImage("frame_2.jpg", None, "valid", []),
    ]
    pils = [noise(5), noise(6), noise(7)]

    wells = build_wells(images, pils, [4, 9, 2], size=32)

    assert wells.crops.shape == (3, 32, 32, 3)
    assert wells.context.shape == (3, 32, 32, 3)
    assert wells.labels.tolist() == [0, 1, 1]
    assert wells.groups.tolist() == [4, 4, 9]
    assert wells.sources.tolist() == ["video", "video", "PXL"]
    assert wells.grades.tolist() == [NORMAL, "Watery Milk", "Curd like Milk"]
    assert wells.image_index.tolist() == [0, 0, 1]
    # Los dos pozos de la misma foto comparten el mismo contexto (los dos tapados)
    np.testing.assert_array_equal(wells.context[0], wells.context[1])


def test_iou():
    assert iou((0, 0, 10, 10), (0, 0, 10, 10)) == 1.0
    assert iou((0, 0, 10, 10), (5, 0, 10, 10)) == pytest.approx(50 / 150)
    assert iou((0, 0, 10, 10), (20, 20, 5, 5)) == 0.0
    assert iou((0, 0, 0, 0), (0, 0, 0, 0)) == 0.0


def test_label_conflicts_only_between_near_identical_frames_and_overlapping_boxes():
    same = noise(8)
    images = [
        MilkImage("a.jpg", None, "train", [(NORMAL, (0, 0, 20, 20)), ("Watery Milk", (40, 0, 20, 20))]),
        MilkImage(
            "b.jpg", None, "valid", [("Blood tinged Milk", (1, 1, 20, 20)), ("Watery Milk", (40, 0, 20, 20))]
        ),
        MilkImage("c.jpg", None, "test", [("Blood tinged Milk", (0, 0, 20, 20))]),
    ]

    conflicts = label_conflicts(images, [same, same, noise(9)])

    assert conflicts == [{"a": "a.jpg", "b": "b.jpg", "grade_a": NORMAL, "grade_b": "Blood tinged Milk"}]


@pytest.fixture
def crop():
    rng = np.random.default_rng(10)
    return rng.integers(30, 220, (40, 40, 3), dtype=np.uint8)


def test_degradations_keep_shape_and_type_and_change_the_image(crop):
    for kind, (_, levels) in DEGRADATIONS.items():
        for level in levels:
            out = degrade(crop[None], kind, level)
            assert out.shape == (1, 40, 40, 3)
            assert out.dtype == np.uint8
            assert not np.array_equal(out[0], crop), (kind, level)


def test_degradation_directions(crop):
    assert brightness(crop, 1.5).mean() > crop.mean() > brightness(crop, 0.5).mean()
    assert brightness(crop, 1.0).tolist() == crop.tolist()
    assert blur(crop, 2).std() < crop.std()
    np.testing.assert_array_equal(rotate(crop, 360), crop)
    assert (rotate(crop, 45)[0, 0] == 0).all()  # la esquina queda con relleno negro
    error_low = np.abs(jpeg(crop, 10).astype(int) - crop).mean()
    error_high = np.abs(jpeg(crop, 90).astype(int) - crop).mean()
    assert error_low > error_high
