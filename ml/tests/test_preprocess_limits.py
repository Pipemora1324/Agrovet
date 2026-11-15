"""Límites exactos del preprocesamiento: la app los replica en Dart, así que un error de un día o de
un decimal aquí cambia la alerta. Complementa test_preprocess.py con casos armados a mano."""

import numpy as np
import pandas as pd
import pytest

from preprocess import MIN_VALID_DAYS, VALID_RANGES, WINDOW_DAYS, build_windows, clean_window


def flat_window(temp=38.5, milk=12.0, feed=10.0):
    return np.tile([temp, milk, feed], (WINDOW_DAYS, 1)).astype(float)


@pytest.mark.parametrize("column, name", [(0, "temperature_c"), (1, "milk_l"), (2, "feed_kg")])
@pytest.mark.parametrize("edge", [0, 1])
def test_range_limits_are_inclusive(column, name, edge):
    window = flat_window()
    window[:, column] = VALID_RANGES[name][edge]

    clean, usable = clean_window(window)

    assert usable
    np.testing.assert_array_equal(clean[:, column], VALID_RANGES[name][edge])


def test_exactly_the_minimum_of_valid_days_is_enough():
    window = flat_window()
    window[: WINDOW_DAYS - MIN_VALID_DAYS, 1] = np.nan
    assert clean_window(window)[1]

    window[WINDOW_DAYS - MIN_VALID_DAYS, 1] = np.nan
    assert not clean_window(window)[1]


def test_integer_input_is_cleaned_as_float():
    clean, usable = clean_window([[38, 12, 10]] * WINDOW_DAYS)
    assert usable
    assert clean.dtype == np.float64


def test_wrong_shape_message_says_what_was_expected():
    with pytest.raises(ValueError, match=r"14x3.*\(13, 3\)"):
        clean_window(np.ones((13, 3)))


def cow_rows(cow_id, n_days, sick, onset):
    return pd.DataFrame({
        "cow_id": cow_id,
        "day": np.arange(n_days),
        "temperature_c": 38.5,
        "milk_l": 12.0 + np.arange(n_days) * 0.01,
        "feed_kg": 10.0,
        "sick": sick,
        "onset_day": onset,
    })


@pytest.fixture
def small_herd():
    healthy = cow_rows(0, 16, False, -1)          # ventanas que terminan en los días 13, 14 y 15
    sick = cow_rows(1, 20, True, 19)              # terminan en 13..18; desde el día 19 ya es clínico
    gap = cow_rows(2, 18, False, -1)
    gap.loc[0:4, "milk_l"] = np.nan               # la primera ventana tiene 9 días válidos de leche
    # Desordenado a propósito: build_windows debe ordenar por vaca y día
    return pd.concat([sick, gap, healthy]).sample(frac=1.0, random_state=0)


def test_windows_of_a_small_herd_are_exact(small_herd):
    X, y, meta = build_windows(small_herd)

    assert list(meta.columns) == ["cow_id", "end_day", "days_to_onset", "sick"]
    assert X.dtype == np.float32 and X.shape == (3 + 6 + 4, WINDOW_DAYS, 3)
    assert y.dtype == np.int32
    assert meta["cow_id"].tolist() == [0] * 3 + [1] * 6 + [2] * 4
    # Vaca sana: 13-15; vaca enferma: 13-18; vaca con faltantes al comienzo: 14-17
    assert meta["end_day"].tolist() == [13, 14, 15, 13, 14, 15, 16, 17, 18, 14, 15, 16, 17]


def test_label_horizon_is_one_to_five_days_inclusive(small_herd):
    _, y, meta = build_windows(small_herd)
    sick = meta["cow_id"] == 1

    assert meta.loc[sick, "days_to_onset"].tolist() == [6, 5, 4, 3, 2, 1]
    assert y[sick.to_numpy()].tolist() == [0, 1, 1, 1, 1, 1]


def test_healthy_cows_never_get_a_positive_label_or_a_distance_to_onset(small_herd):
    _, y, meta = build_windows(small_herd)
    healthy = (~meta["sick"]).to_numpy()

    assert healthy.sum() == 7
    assert (y[healthy] == 0).all()
    assert meta.loc[healthy, "days_to_onset"].isna().all()


def test_an_unusable_window_skips_only_itself(small_herd):
    _, _, meta = build_windows(small_herd)
    # La ventana que termina en el día 13 no tiene datos suficientes; las siguientes sí entran
    assert meta.loc[meta["cow_id"] == 2, "end_day"].tolist() == [14, 15, 16, 17]
