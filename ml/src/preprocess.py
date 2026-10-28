"""Preprocesamiento de ventanas de 14 días, compartido por entrenamiento, exportación y vectores de prueba.

La app reimplementa exactamente esta lógica en Dart, así que cualquier cambio aquí debe
reflejarse en model_config.json y en test_vectors.json.

Pasos para una ventana cruda de 14 x 3 (temperatura °C, leche L, alimento kg):
1. Un valor vacío o fuera de rango se considera faltante.
2. Si una variable tiene menos de MIN_VALID_DAYS valores válidos, la ventana no se usa.
3. Los faltantes se rellenan con el último valor válido anterior; si faltan al comienzo,
   con el primer valor válido siguiente.
4. La base de cada variable es la media de los primeros BASE_DAYS días.
5. Temperatura: (t - base) / TEMP_SCALE. Leche y alimento: (x / base - 1) / RATIO_SCALE.
"""

import numpy as np

FEATURES = ("temperature_c", "milk_l", "feed_kg")
WINDOW_DAYS = 14
BASE_DAYS = 7
MIN_VALID_DAYS = 10
TEMP_SCALE = 0.5
RATIO_SCALE = 0.1
HORIZON_MIN_DAYS = 1
HORIZON_MAX_DAYS = 5
VALID_RANGES = {
    "temperature_c": (35.0, 42.0),
    "milk_l": (0.5, 45.0),
    "feed_kg": (0.5, 35.0),
}


def clean_window(raw):
    """Devuelve (ventana_limpia, es_utilizable). raw: array 14 x 3 con posibles NaN."""
    window = np.array(raw, dtype=np.float64)
    if window.shape != (WINDOW_DAYS, len(FEATURES)):
        raise ValueError(f"Se esperaba una ventana {WINDOW_DAYS}x{len(FEATURES)}, llegó {window.shape}")

    for col, name in enumerate(FEATURES):
        low, high = VALID_RANGES[name]
        values = window[:, col]
        valid = ~np.isnan(values) & (values >= low) & (values <= high)
        if valid.sum() < MIN_VALID_DAYS:
            return window, False
        last = values[np.argmax(valid)]  # primer válido, para los faltantes iniciales
        for day in range(WINDOW_DAYS):
            if valid[day]:
                last = values[day]
            else:
                values[day] = last
    return window, True


def normalize_window(clean):
    """Normaliza una ventana ya limpia con la línea base de sus primeros días."""
    base = clean[:BASE_DAYS].mean(axis=0)
    normalized = np.empty_like(clean)
    normalized[:, 0] = (clean[:, 0] - base[0]) / TEMP_SCALE
    normalized[:, 1:] = (clean[:, 1:] / base[1:] - 1.0) / RATIO_SCALE
    return normalized


def preprocess_window(raw):
    """Limpia y normaliza. Devuelve None si la ventana no tiene datos suficientes."""
    clean, usable = clean_window(raw)
    if not usable:
        return None
    return normalize_window(clean)


def build_windows(df):
    """Arma todas las ventanas etiquetadas del dataset.

    Etiqueta 1 si el inicio clínico ocurre entre 1 y 5 días después del último día de la
    ventana. Se descartan las ventanas cuyo último día es el inicio clínico o posterior.
    Devuelve (X, y, meta) con meta = DataFrame de cow_id, end_day, days_to_onset, sick.
    """
    import pandas as pd

    xs, ys, meta = [], [], []
    for cow_id, cow in df.sort_values(["cow_id", "day"]).groupby("cow_id", sort=True):
        values = cow[list(FEATURES)].to_numpy(dtype=np.float64)
        days = cow["day"].to_numpy()
        sick = bool(cow["sick"].iloc[0])
        onset = int(cow["onset_day"].iloc[0])
        for end in range(WINDOW_DAYS - 1, len(cow)):
            end_day = int(days[end])
            if sick and end_day >= onset:
                break
            window = preprocess_window(values[end - WINDOW_DAYS + 1:end + 1])
            if window is None:
                continue
            days_to_onset = onset - end_day if sick else np.nan
            label = int(sick and HORIZON_MIN_DAYS <= days_to_onset <= HORIZON_MAX_DAYS)
            xs.append(window)
            ys.append(label)
            meta.append((cow_id, end_day, days_to_onset, sick))

    X = np.stack(xs).astype(np.float32)
    y = np.array(ys, dtype=np.int32)
    meta = pd.DataFrame(meta, columns=["cow_id", "end_day", "days_to_onset", "sick"])
    return X, y, meta


def traffic_light(probability, threshold):
    """Color del semáforo: verde < umbral/2, amarillo [umbral/2, umbral), rojo >= umbral."""
    if probability >= threshold:
        return "red"
    if probability >= threshold * 0.5:
        return "yellow"
    return "green"
