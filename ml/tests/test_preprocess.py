import numpy as np
import pytest

from generate_dataset import DatasetParams, generate
from preprocess import (BASE_DAYS, WINDOW_DAYS, build_windows, clean_window, normalize_window,
                        preprocess_window, traffic_light)


def flat_window(temp=38.5, milk=12.0, feed=10.0):
    return np.tile([temp, milk, feed], (WINDOW_DAYS, 1)).astype(float)


def test_flat_window_normalizes_to_zero():
    np.testing.assert_allclose(preprocess_window(flat_window()), 0.0, atol=1e-12)


def test_normalization_formula():
    raw = flat_window()
    raw[-1] = [39.5, 9.0, 8.0]
    norm = preprocess_window(raw)
    assert norm[-1, 0] == pytest.approx((39.5 - 38.5) / 0.5)
    assert norm[-1, 1] == pytest.approx((9.0 / 12.0 - 1) / 0.1)
    assert norm[-1, 2] == pytest.approx((8.0 / 10.0 - 1) / 0.1)


def test_base_uses_only_first_days():
    raw = flat_window()
    raw[BASE_DAYS:, 0] = 40.0
    norm = preprocess_window(raw)
    np.testing.assert_allclose(norm[:BASE_DAYS, 0], 0.0)
    np.testing.assert_allclose(norm[BASE_DAYS:, 0], (40.0 - 38.5) / 0.5)


@pytest.mark.parametrize("bad", [np.nan, 3.85, 101.3])
def test_invalid_temperature_takes_previous_value(bad):
    raw = flat_window()
    raw[5, 0] = 38.9
    raw[6, 0] = bad
    clean, usable = clean_window(raw)
    assert usable
    assert clean[6, 0] == 38.9


def test_invalid_values_at_start_take_first_valid_value():
    raw = flat_window()
    raw[0, 1] = 120.0  # cero de más
    raw[1, 1] = 11.0
    clean, _ = clean_window(raw)
    assert clean[0, 1] == 11.0


def test_zero_feed_is_treated_as_missing():
    raw = flat_window()
    raw[3, 2] = 0.0
    clean, _ = clean_window(raw)
    assert clean[3, 2] == 10.0


def test_window_with_too_many_missing_values_is_rejected():
    raw = flat_window()
    raw[:5, 1] = np.nan
    assert preprocess_window(raw) is None


def test_wrong_shape_raises():
    with pytest.raises(ValueError):
        clean_window(np.zeros((13, 3)))


def test_normalize_does_not_modify_input():
    raw = flat_window()
    copy = raw.copy()
    normalize_window(raw)
    np.testing.assert_array_equal(raw, copy)


@pytest.fixture(scope="module")
def windows():
    df = generate(DatasetParams(n_cows=60))
    return df, build_windows(df)


def test_no_window_ends_on_or_after_onset(windows):
    _, (_, _, meta) = windows
    sick = meta[meta["sick"]]
    assert (sick["days_to_onset"] >= 1).all()


def test_label_is_one_only_within_horizon(windows):
    _, (_, y, meta) = windows
    expected = (meta["sick"] & meta["days_to_onset"].between(1, 5)).astype(int).to_numpy()
    np.testing.assert_array_equal(y, expected)


def test_each_sick_cow_has_positive_windows(windows):
    df, (_, y, meta) = windows
    sick_cows = df.loc[df["sick"], "cow_id"].unique()
    positive_cows = meta.loc[y == 1, "cow_id"].unique()
    assert set(sick_cows) == set(positive_cows)


def test_windows_have_expected_shape_and_no_nan(windows):
    _, (X, _, _) = windows
    assert X.shape[1:] == (WINDOW_DAYS, 3)
    assert X.dtype == np.float32
    assert not np.isnan(X).any()


def test_healthy_cow_produces_all_windows(windows):
    df, (_, _, meta) = windows
    healthy = df.loc[~df["sick"], "cow_id"].unique()
    per_cow = meta[meta["cow_id"].isin(healthy)].groupby("cow_id").size()
    assert per_cow.max() == 60 - WINDOW_DAYS + 1


@pytest.mark.parametrize("prob,color", [(0.10, "green"), (0.25, "yellow"), (0.49, "yellow"),
                                        (0.50, "red"), (0.95, "red")])
def test_traffic_light(prob, color):
    assert traffic_light(prob, threshold=0.5) == color


def test_traffic_light_boundary_is_yellow_at_half_threshold():
    assert traffic_light(0.2, threshold=0.4) == "yellow"
    assert traffic_light(np.nextafter(0.2, 0), threshold=0.4) == "green"
