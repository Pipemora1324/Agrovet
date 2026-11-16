import hashlib

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


# Huella del dataset antes de agregar los parámetros de finca: con los valores por defecto el
# generador tiene que dar exactamente los mismos datos con los que se entrenó el modelo desplegado.
DEFAULT_FINGERPRINT_40_COWS = "f50edb22fc11b3aac956b16055fa34f3e981772ff322737e3ff9454afaadc69a"


def fingerprint(frame):
    return hashlib.sha256(pd.util.hash_pandas_object(frame, index=True).to_numpy().tobytes()).hexdigest()


def test_default_farm_parameters_reproduce_the_training_data():
    assert fingerprint(generate(DatasetParams(n_cows=40))) == DEFAULT_FINGERPRINT_40_COWS


def healthy_clean(frame):
    return frame[~frame["sick"] & ~frame["is_erroneous"]]


def test_farm_base_values_move_the_herd():
    base = healthy_clean(generate(DatasetParams(n_cows=80)))
    farm = healthy_clean(generate(DatasetParams(n_cows=80, base_milk_mean=24.0, base_feed_mean=17.0,
                                                base_temp_mean=38.9)))
    assert farm["milk_l"].mean() - base["milk_l"].mean() == pytest.approx(11.0, abs=1.5)
    assert farm["feed_kg"].mean() - base["feed_kg"].mean() == pytest.approx(6.0, abs=1.0)
    assert farm["temperature_c"].mean() - base["temperature_c"].mean() == pytest.approx(0.3, abs=0.05)
    per_cow = generate(DatasetParams(n_cows=80, base_milk_sd=0.0, base_feed_sd=0.0))
    first_day = healthy_clean(per_cow[per_cow["day"] == 0])
    # Sin dispersión entre vacas solo queda el ruido diario (5 % de la leche, 6 % del alimento)
    assert first_day["milk_l"].std() < 1.2
    assert first_day["feed_kg"].std() < 1.2


def test_noise_and_heat_stress_scales():
    def daily_spread(frame):
        return frame.groupby("cow_id")["temperature_c"].diff().std()

    quiet = healthy_clean(generate(DatasetParams(n_cows=60, noise_scale=0.0, heat_stress_scale=0.0)))
    base = healthy_clean(generate(DatasetParams(n_cows=60)))
    noisy = healthy_clean(generate(DatasetParams(n_cows=60, noise_scale=3.0)))
    assert daily_spread(quiet) < daily_spread(base) < daily_spread(noisy)
    assert not quiet["heat_stress"].any()
    hot = generate(DatasetParams(n_cows=60, heat_stress_scale=2.0))
    assert hot["heat_stress"].any()
    assert healthy_clean(hot)["temperature_c"].max() > base["temperature_c"].max()


def test_severity_range_is_a_parameter():
    cows = generate(DatasetParams(n_cows=80, severity_min=0.3, severity_max=0.5)).groupby("cow_id").first()
    assert cows.loc[cows["sick"], "severity"].between(0.3, 0.5).all()
