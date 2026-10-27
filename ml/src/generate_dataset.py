"""Genera el dataset sintético de registros diarios por vaca.

Los datos imitan lo que la literatura describe para la fase subclínica de la mastitis:
en los días previos a los síntomas clínicos sube un poco la temperatura y bajan la leche
y el consumo de alimento. Para que el problema no sea trivial se agregan factores que
producen señales parecidas sin enfermedad (celo, estrés calórico) y registros erróneos
como los que se cometen al digitar en campo.

Las métricas obtenidas con estos datos NO validan la hipótesis del proyecto; sirven
para comprobar que el pipeline funciona de punta a punta.
"""

import argparse
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pandas as pd

ML_DIR = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ML_DIR / "data" / "daily_records.csv"


@dataclass(frozen=True)
class DatasetParams:
    n_cows: int = 600
    n_days: int = 60
    sick_fraction: float = 0.35
    seed: int = 42
    error_fraction: float = 0.02
    estrus_cycle_days: float = 21.0
    # Primer y último día posibles de inicio clínico: deja al menos 14 días de historia
    # y algunos días después del inicio dentro del periodo observado.
    min_onset_day: int = 20
    max_onset_day: int = 56
    subclinical_min_days: int = 5
    subclinical_max_days: int = 7


def _heat_stress_days(rng, n_days):
    """Rachas de estrés calórico compartidas por todo el hato (dependen del clima)."""
    stress = np.zeros(n_days)
    for _ in range(rng.integers(2, 5)):
        length = rng.integers(2, 6)
        start = rng.integers(0, n_days - length)
        intensity = rng.uniform(0.5, 1.0)
        stress[start:start + length] = np.maximum(stress[start:start + length], intensity)
    return stress


def _estrus_effect(rng, n_days, cycle_days):
    """Intensidad del celo por día (0 = sin celo). Parte de las vacas están preñadas y no ciclan."""
    effect = np.zeros(n_days)
    if rng.random() < 0.3:
        return effect
    cycle = max(18, int(round(rng.normal(cycle_days, 1.0))))
    day = int(rng.integers(0, cycle))
    while day < n_days:
        effect[day] = 1.0
        if day + 1 < n_days:
            effect[day + 1] = 0.4
        day += cycle
    return effect


def _disease_profile(n_days, onset, subclinical_days, severity):
    """Desviación relativa por día (0 antes de la fase subclínica, crece hasta el inicio clínico)."""
    profile = np.zeros(n_days)
    start = onset - subclinical_days
    for day in range(max(start, 0), n_days):
        if day < onset:
            progress = (day - start + 1) / subclinical_days
            profile[day] = severity * 0.45 * progress ** 1.5
        else:
            # Fase clínica: el efecto salta y se mantiene
            profile[day] = severity * min(1.0, 0.7 + 0.1 * (day - onset))
    return profile


def _inject_errors(rng, temp, milk, feed, error_fraction):
    """Errores de digitación típicos: decimal corrido, Fahrenheit, valor vacío o cero."""
    n = len(temp)
    flags = rng.random(n) < error_fraction
    kinds = rng.integers(0, 5, n)
    for i in np.flatnonzero(flags):
        kind = kinds[i]
        if kind == 0:
            temp[i] = temp[i] / 10  # 3.86 en vez de 38.6
        elif kind == 1:
            temp[i] = temp[i] * 9 / 5 + 32  # anotada en Fahrenheit
        elif kind == 2:
            milk[i] = milk[i] * 10  # cero de más
        elif kind == 3:
            feed[i] = 0.0  # se dejó en cero
        else:
            column = (temp, milk, feed)[rng.integers(0, 3)]
            column[i] = np.nan  # no se registró
    return flags


def generate(params=DatasetParams()):
    rng = np.random.default_rng(params.seed)
    n_sick = int(round(params.n_cows * params.sick_fraction))
    sick_ids = set(rng.choice(params.n_cows, size=n_sick, replace=False).tolist())
    heat_stress = _heat_stress_days(rng, params.n_days)
    days = np.arange(params.n_days)

    frames = []
    for cow in range(params.n_cows):
        base_temp = np.clip(rng.normal(38.6, 0.15), 38.2, 39.0)
        base_milk = np.clip(rng.normal(13.0, 3.5), 5.0, 25.0)
        base_feed = np.clip(rng.normal(11.0, 2.0), 6.0, 17.0)
        lactation_slope = rng.uniform(-0.004, 0.0)  # leve caída diaria de la producción
        heat_sensitivity = rng.uniform(0.5, 1.5)

        estrus = _estrus_effect(rng, params.n_days, params.estrus_cycle_days)
        stress = heat_stress * heat_sensitivity

        sick = cow in sick_ids
        if sick:
            onset = int(rng.integers(params.min_onset_day, params.max_onset_day + 1))
            subclinical_days = int(rng.integers(params.subclinical_min_days,
                                                params.subclinical_max_days + 1))
            severity = float(rng.uniform(0.6, 1.4))
            disease = _disease_profile(params.n_days, onset, subclinical_days, severity)
        else:
            onset, subclinical_days, severity = -1, 0, 0.0
            disease = np.zeros(params.n_days)

        temp = (base_temp
                + rng.normal(0, 0.15, params.n_days)
                + 0.4 * estrus
                + 0.4 * stress
                + 1.6 * disease)
        milk_factor = (1 + lactation_slope * days
                       + rng.normal(0, 0.05, params.n_days)
                       - 0.08 * estrus
                       - 0.06 * stress
                       - 0.40 * disease)
        feed_factor = (1
                       + rng.normal(0, 0.06, params.n_days)
                       - 0.08 * estrus
                       - 0.09 * stress
                       - 0.30 * disease)
        milk = base_milk * np.clip(milk_factor, 0.05, None)
        feed = base_feed * np.clip(feed_factor, 0.05, None)

        erroneous = _inject_errors(rng, temp, milk, feed, params.error_fraction)

        if sick:
            days_to_onset = (onset - days).astype(float)
        else:
            days_to_onset = np.full(params.n_days, np.nan)

        frames.append(pd.DataFrame({
            "cow_id": cow,
            "day": days,
            "temperature_c": np.round(temp, 2),
            "milk_l": np.round(milk, 2),
            "feed_kg": np.round(feed, 2),
            "sick": sick,
            "onset_day": onset,
            "days_to_onset": days_to_onset,
            "subclinical_days": subclinical_days,
            "severity": round(severity, 3),
            "in_estrus": estrus >= 1.0,
            "heat_stress": stress > 0,
            "is_erroneous": erroneous,
        }))

    return pd.concat(frames, ignore_index=True)


def main():
    parser = argparse.ArgumentParser(description="Genera el dataset sintético de AgroVet.")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--seed", type=int, default=DatasetParams.seed)
    args = parser.parse_args()

    df = generate(DatasetParams(seed=args.seed))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(args.output, index=False)

    cows = df.groupby("cow_id")["sick"].first()
    print(f"Registros: {len(df)}  vacas: {len(cows)}  enfermas: {cows.sum()} "
          f"({cows.mean():.1%})  erróneos: {df['is_erroneous'].mean():.2%}")
    print(f"Guardado en {args.output}")


if __name__ == "__main__":
    main()
