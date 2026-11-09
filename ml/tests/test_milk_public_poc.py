import numpy as np
from PIL import Image

from milk_public_poc import build_crops, dhash, group_images, source_of


def _noise(seed):
    rng = np.random.default_rng(seed)
    return Image.fromarray(rng.integers(0, 256, size=(360, 640, 3), dtype=np.uint8))


def test_phone_session_is_detected_by_name():
    assert source_of("PXL_20260526_034329281.jpg") == "PXL"
    assert source_of("frame_0038.jpg") == "video"


def test_dhash_has_64_bits():
    assert dhash(_noise(0)).shape == (64,)


def test_near_identical_frames_share_a_group():
    a, b = _noise(1), _noise(2)
    images = [{"name": n} for n in ("frame_0001.jpg", "frame_0002.jpg", "frame_0099.jpg")]
    groups = group_images(images, [a, a.copy(), b])
    assert groups[0] == groups[1] != groups[2]


def test_each_well_becomes_a_labeled_crop_and_tiny_boxes_are_skipped():
    image = {"source": "video", "boxes": [("Normal Milk", (10, 10, 200, 200)),
                                          ("Watery Milk", (300, 50, 150, 150)),
                                          ("Curd like Milk", (500, 300, 20, 20))]}
    crops, labels, groups, sources, grades = build_crops([image], [_noise(3)], [7])
    assert crops.shape == (2, 224, 224, 3)
    assert labels.tolist() == [0, 1]
    assert groups.tolist() == [7, 7] and sources.tolist() == ["video", "video"]
    assert grades.tolist() == ["Normal Milk", "Watery Milk"]
