"""Convierte el LSTM entrenado a TFLite y escribe models/model_config.json.

- Reconstruye el modelo con batch fijo de 1 (entrada [1, 14, 3]) y copia los pesos.
- Convierte solo con operaciones TFLITE_BUILTINS (sin Flex), para que la app no necesite
  dependencias extra.
- Compara Keras y TFLite sobre todo el set de test y reporta la diferencia máxima.
"""

import hashlib
import json
import tempfile
from pathlib import Path

import numpy as np
import tensorflow as tf

from preprocess import (BASE_DAYS, FEATURES, HORIZON_MAX_DAYS, HORIZON_MIN_DAYS, MIN_VALID_DAYS,
                        RATIO_SCALE, TEMP_SCALE, VALID_RANGES, WINDOW_DAYS)
from train_lstm import MODEL_PATH, REPORTS_DIR, SYNTHETIC_NOTE, build_model, load_split_windows

ML_DIR = Path(__file__).resolve().parents[1]
TFLITE_PATH = ML_DIR / "models" / "mastitis_lstm.tflite"
CONFIG_PATH = ML_DIR / "models" / "model_config.json"
MODEL_VERSION = "1.0.0-synthetic"


def make_interpreter(model_content):
    try:
        from ai_edge_litert.interpreter import Interpreter
    except ImportError:
        Interpreter = tf.lite.Interpreter
    interpreter = Interpreter(model_content=model_content)
    interpreter.allocate_tensors()
    return interpreter


def run_tflite(interpreter, windows):
    input_index = interpreter.get_input_details()[0]["index"]
    output_index = interpreter.get_output_details()[0]["index"]
    out = np.empty(len(windows), dtype=np.float32)
    for i, window in enumerate(windows):
        interpreter.set_tensor(input_index, window[np.newaxis].astype(np.float32))
        interpreter.invoke()
        out[i] = interpreter.get_tensor(output_index)[0, 0]
    return out


def convert(keras_model):
    export_model = build_model(batch_size=1, unroll=True)
    export_model.set_weights(keras_model.get_weights())

    # Se pasa por un SavedModel para que los pesos queden congelados como constantes
    with tempfile.TemporaryDirectory() as saved_dir:
        export_model.export(saved_dir, format="tf_saved_model", verbose=False)
        converter = tf.lite.TFLiteConverter.from_saved_model(saved_dir)
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
        return converter.convert()


def used_ops(interpreter):
    return sorted({op["op_name"] for op in interpreter._get_ops_details()})


def main():
    keras_model = tf.keras.models.load_model(MODEL_PATH)
    tflite_model = convert(keras_model)
    TFLITE_PATH.write_bytes(tflite_model)

    interpreter = make_interpreter(tflite_model)
    ops = used_ops(interpreter)
    if any(op.startswith("Flex") or op in ("VAR_HANDLE", "READ_VARIABLE", "WHILE") for op in ops):
        raise SystemExit(f"El modelo tiene operaciones no esperadas: {ops}")

    with open(REPORTS_DIR / "metrics.json", encoding="utf-8") as fh:
        metrics = json.load(fh)
    threshold = metrics["threshold"]

    _, parts = load_split_windows()
    X_test, _, _ = parts["test"]
    prob_keras = keras_model.predict(X_test, verbose=0).ravel()
    prob_tflite = run_tflite(interpreter, X_test)
    if not np.isfinite(prob_tflite).all():
        raise SystemExit("El modelo TFLite produjo valores no finitos")
    diff = np.abs(prob_keras - prob_tflite)
    agreement = float(np.mean((prob_keras >= threshold) == (prob_tflite >= threshold)))

    details = interpreter.get_input_details()[0]
    config = {
        "model_file": TFLITE_PATH.name,
        "model_version": MODEL_VERSION,
        "trained_on": "synthetic",
        "note": SYNTHETIC_NOTE,
        "tflite_sha256": hashlib.sha256(tflite_model).hexdigest(),
        "input": {
            "shape": [int(d) for d in details["shape"]],
            "dtype": "float32",
            "features": list(FEATURES),
        },
        "output": {"shape": [1, 1], "meaning": "Probabilidad de síntomas clínicos de mastitis "
                                               f"en {HORIZON_MIN_DAYS} a {HORIZON_MAX_DAYS} días"},
        "preprocessing": {
            "window_days": WINDOW_DAYS,
            "base_days": BASE_DAYS,
            "min_valid_days": MIN_VALID_DAYS,
            "valid_ranges": {name: list(bounds) for name, bounds in VALID_RANGES.items()},
            "imputation": "Faltante o fuera de rango: último valor válido anterior; "
                          "al comienzo, primer valor válido siguiente.",
            "temperature_c": {"method": "difference", "scale": TEMP_SCALE,
                              "formula": "(t - base) / scale"},
            "milk_l": {"method": "ratio", "scale": RATIO_SCALE, "formula": "(x / base - 1) / scale"},
            "feed_kg": {"method": "ratio", "scale": RATIO_SCALE, "formula": "(x / base - 1) / scale"},
            "base": f"Media de los primeros {BASE_DAYS} días de la ventana, ya limpios.",
        },
        "threshold": threshold,
        "traffic_light": {
            "green": {"min": 0.0, "max_exclusive": round(threshold * 0.5, 6)},
            "yellow": {"min": round(threshold * 0.5, 6), "max_exclusive": threshold},
            "red": {"min": threshold, "max": 1.0},
        },
    }
    with open(CONFIG_PATH, "w", encoding="utf-8") as fh:
        json.dump(config, fh, ensure_ascii=False, indent=2)

    export_report = {
        "note": SYNTHETIC_NOTE,
        "tflite_bytes": len(tflite_model),
        "ops": ops,
        "test_windows": int(len(X_test)),
        "max_abs_diff_keras_vs_tflite": float(diff.max()),
        "mean_abs_diff_keras_vs_tflite": float(diff.mean()),
        "same_decision_rate": agreement,
    }
    with open(REPORTS_DIR / "export.json", "w", encoding="utf-8") as fh:
        json.dump(export_report, fh, ensure_ascii=False, indent=2)

    print(json.dumps(export_report, ensure_ascii=False, indent=2))
    print(f"Modelo: {TFLITE_PATH}  Config: {CONFIG_PATH}")


if __name__ == "__main__":
    main()
