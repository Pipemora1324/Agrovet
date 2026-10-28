"""Escribe models/test_vectors.json: casos para comprobar que la app reproduce Python.

Se toman 8 ventanas de vacas del set de test (dos por tipo): sanas, en fase subclínica,
con celo en los últimos días y con un registro erróneo. Para cada una se guarda la
ventana cruda (null = dato vacío), la ventana normalizada esperada, la probabilidad que
da el modelo TFLite y el color del semáforo. La app debe coincidir con tolerancia 1e-4.
"""

import json

import numpy as np
import pandas as pd

from export_tflite import CONFIG_PATH, TFLITE_PATH, make_interpreter, run_tflite
from preprocess import FEATURES, VALID_RANGES, WINDOW_DAYS, preprocess_window, traffic_light
from train_lstm import DATA_PATH, SYNTHETIC_NOTE, split_cows

VECTORS_PATH = TFLITE_PATH.parent / "test_vectors.json"
TOLERANCE = 1e-4
CASES_PER_KIND = 2
# Los dos casos erróneos cubren errores distintos: un dato vacío y una temperatura imposible
ERROR_SUBTYPES = ("missing", "temperature_c")


def candidate_windows(df, test_ids):
    """Recorre las ventanas de vacas de test con su información de contexto."""
    for cow_id, cow in df[df["cow_id"].isin(test_ids)].groupby("cow_id", sort=True):
        cow = cow.sort_values("day").reset_index(drop=True)
        onset = int(cow["onset_day"].iloc[0])
        sick = bool(cow["sick"].iloc[0])
        for end in range(WINDOW_DAYS - 1, len(cow)):
            if sick and end >= onset:
                break
            rows = cow.iloc[end - WINDOW_DAYS + 1:end + 1]
            yield cow_id, end, sick, onset, rows


def classify(sick, onset, end, rows):
    erroneous = bool(rows["is_erroneous"].any())
    if erroneous:
        return "erroneous_record"
    if sick and 1 <= onset - end <= 3:
        return "subclinical"
    if sick:
        return None
    if rows["in_estrus"].iloc[-3:].any() and not rows["heat_stress"].any():
        return "estrus"
    if not rows["in_estrus"].any() and not rows["heat_stress"].any():
        return "healthy"
    return None


def error_subtype(raw):
    if np.isnan(raw).any():
        return "missing"
    for col, name in enumerate(FEATURES):
        low, high = VALID_RANGES[name]
        if ((raw[:, col] < low) | (raw[:, col] > high)).any():
            return name
    return None


def main():
    df = pd.read_csv(DATA_PATH)
    _, _, test_ids = split_cows(df)
    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    threshold = config["threshold"]
    interpreter = make_interpreter(TFLITE_PATH.read_bytes())

    wanted = ("healthy", "subclinical", "estrus", "erroneous_record")
    chosen = {kind: [] for kind in wanted}
    used_cows, used_errors = set(), set()
    for cow_id, end, sick, onset, rows in candidate_windows(df, test_ids):
        kind = classify(sick, onset, end, rows)
        if kind is None or len(chosen[kind]) >= CASES_PER_KIND or cow_id in used_cows:
            continue
        raw = rows[list(FEATURES)].to_numpy(dtype=np.float64)
        normalized = preprocess_window(raw)
        if normalized is None:
            continue
        if kind == "erroneous_record":
            subtype = error_subtype(raw)
            if subtype not in ERROR_SUBTYPES or subtype in used_errors:
                continue
            used_errors.add(subtype)
        chosen[kind].append((cow_id, end, sick, onset, raw, normalized))
        used_cows.add(cow_id)
        if all(len(v) == CASES_PER_KIND for v in chosen.values()):
            break

    cases = []
    for kind in wanted:
        for number, (cow_id, end, sick, onset, raw, normalized) in enumerate(chosen[kind], start=1):
            probability = float(run_tflite(interpreter, normalized[np.newaxis].astype(np.float32))[0])
            cases.append({
                "id": f"{kind}_{number}",
                "kind": kind,
                "source": {"cow_id": int(cow_id), "end_day": int(end),
                           "days_to_onset": int(onset - end) if sick else None},
                "raw_window": [[None if np.isnan(v) else float(v) for v in day] for day in raw],
                "expected_normalized": normalized.tolist(),
                "expected_probability": probability,
                "expected_color": traffic_light(probability, threshold),
            })

    if len(cases) != CASES_PER_KIND * len(wanted):
        raise SystemExit(f"Solo se encontraron {len(cases)} casos")

    vectors = {
        "note": SYNTHETIC_NOTE,
        "model_file": config["model_file"],
        "model_version": config["model_version"],
        "tflite_sha256": config["tflite_sha256"],
        "features": list(FEATURES),
        "threshold": threshold,
        "tolerance": TOLERANCE,
        "cases": cases,
    }
    VECTORS_PATH.write_text(json.dumps(vectors, ensure_ascii=False, indent=2), encoding="utf-8")
    for case in cases:
        print(f"{case['id']:<22} prob={case['expected_probability']:.6f}  {case['expected_color']}")
    print(f"Guardado en {VECTORS_PATH}")


if __name__ == "__main__":
    main()
