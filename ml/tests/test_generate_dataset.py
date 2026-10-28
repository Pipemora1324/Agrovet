import numpy as np
import pandas as pd
import pytest

from generate_dataset import DatasetParams, generate


@pytest.fixture(scope="module")
def df():
    return generate(DatasetParams())


@pytest.fixture(scope="module")
def cows(df):
    return df.groupby("cow_id").first()


def test_size_matches_parameters(df):
    assert len(df) == 600 * 60
    assert df["cow_id"].nunique() == 600
    assert df.groupby("cow_id")["day"].apply(list).map(lambda d: d == list(range(60))).all()


def test_exactly_35_percent_of_cows_get_sick(cows):
    assert cows["sick"].sum() == round(600 * 0.35)


def test_about_2_percent_of_records_are_erroneous(df):
    assert 0.015 <= df["is_erroneous"].mean() <= 0.025


def test_same_seed_gives_same_dataset():
    params = DatasetParams(n_cows=40)
    pd.testing.assert_frame_equal(generate(params), generate(params))


def test_different_seed_gives_different_dataset():
    a = generate(DatasetParams(n_cows=40, seed=1))
    b = generate(DatasetParams(n_cows=40, seed=2))
    assert not a["temperature_c"].equals(b["temperature_c"])


def test_days_to_onset_is_empty_for_healthy_cows(df):
    healthy = df[~df["sick"]]
    assert healthy["days_to_onset"].isna().all()
    assert (healthy["onset_day"] == -1).all()


def test_days_to_onset_counts_down_and_turns_negative(df):
    sick = df[df["sick"]]
    assert (sick["days_to_onset"] == sick["onset_day"] - sick["day"]).all()
    after_onset = sick[sick["day"] > sick["onset_day"]]
    assert (after_onset["days_to_onset"] < 0).all()


def test_onset_and_subclinical_phase_within_bounds(cows):
    sick = cows[cows["sick"]]
    assert sick["onset_day"].between(20, 56).all()
    assert sick["subclinical_days"].between(5, 7).all()
    assert sick["severity"].between(0.6, 1.4).all()


def test_correct_records_stay_in_plausible_ranges(df):
    ok = df[~df["is_erroneous"]]
    # La fiebre de una mastitis clínica severa puede pasar de 41,5 °C
    assert ok["temperature_c"].between(37.0, 42.0).all()
    assert (ok["milk_l"] > 0).all() and (ok["milk_l"] < 40).all()
    assert (ok["feed_kg"] > 0).all() and (ok["feed_kg"] < 30).all()


def test_erroneous_records_include_missing_values(df):
    values = df[["temperature_c", "milk_l", "feed_kg"]]
    assert values[df["is_erroneous"]].isna().any(axis=1).sum() > 0
    assert values[~df["is_erroneous"]].notna().all().all()


def test_subclinical_phase_raises_temperature_and_lowers_milk(df):
    ok = df[df["sick"] & ~df["is_erroneous"]]
    day_before = ok[ok["days_to_onset"] == 1].set_index("cow_id")
    week_before = ok[ok["days_to_onset"] == 10].set_index("cow_id")
    common = day_before.index.intersection(week_before.index)
    temp_change = day_before.loc[common, "temperature_c"] - week_before.loc[common, "temperature_c"]
    milk_ratio = day_before.loc[common, "milk_l"] / week_before.loc[common, "milk_l"]
    assert temp_change.mean() > 0.3
    assert np.median(milk_ratio) < 0.95


def test_estrus_and_heat_stress_are_present(df):
    assert df["in_estrus"].mean() > 0.01
    assert df["heat_stress"].any()
    assert df[~df["sick"]]["in_estrus"].any()
