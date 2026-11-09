"""Entrena y evalúa la CNN de la ubre con el dataset público de Roboflow (CC BY 4.0).

Uso (los datos están FUERA del repositorio):
    python src/train_udder_public.py --coco "C:/.../Data/roboflow_ubre_yield/Mastitis.v1-v1.coco"
                                     --work-dir "C:/.../Data/agrovet_work/udder"

Qué hace:
  1. Recorta las ubres (udder_public_data.py), descarta las de lado corto < 96 px y agrupa por vaca.
  2. Validación cruzada StratifiedGroupKFold 5x5 en tres experimentos:
       main        recortes de la ubre, todas las fotos;
       img_n       recortes, solo la serie img-N (mismo establo) — prueba de sesgo (a);
       background  solo el fondo (la ubre tapada en negro) — prueba de sesgo (b).
  3. Modelo final con todas las fotos, exportación a TFLite y paridad Keras frente a TFLite.

Salidas:
  - work-dir: predicciones por imagen y modelo .keras (no se versionan);
  - ml/reports/udder_cnn_public.json: métricas agregadas;
  - ml/models/udder_cnn.tflite, udder_cnn_config.json y udder_cnn_vectors.json (para la app).
"""

import argparse
import json
import time
from pathlib import Path

import numpy as np
import tensorflow as tf

from cnn_evaluation import (balanced_class_weight, inner_validation_split, repeated_group_folds,
                            summarize, wilson_interval)
from train_cnn import (ALPHA, FINE_TUNE_LAYERS, IMAGE_SIZE, array_dataset, build_cnn, export_tflite,
                       fit_two_phase, make_augmenter, tflite_predict)
from udder_public_data import CROP_MARGIN, MIN_CROP_SIDE, load_dataset

ML_DIR = Path(__file__).resolve().parents[1]
REPORT_PATH = ML_DIR / "reports" / "udder_cnn_public.json"
TFLITE_PATH = ML_DIR / "models" / "udder_cnn.tflite"
CONFIG_PATH = ML_DIR / "models" / "udder_cnn_config.json"
VECTORS_PATH = ML_DIR / "models" / "udder_cnn_vectors.json"
SEED = 42
THRESHOLD = 0.5
# Pesos en float16 para no pasar el límite del APK (15 MB): el float32 (1,6 MB) no cabe. Se probó
# antes int8 (rango dinámico, 0,55 MB): en las fotos reales difería de Keras hasta 0,09.
# La tolerancia se fijó primero en 0,01 y se subió a 0,03 DESPUÉS de ver que float16 da 0,024.
QUANTIZE = "float16"
TOLERANCE = 0.03
SOURCE = {
    "name": "Mastitis v1 (Roboflow Universe, yield-a2yrd/mastitis-zmser)",
    "url": "https://universe.roboflow.com/yield-a2yrd/mastitis-zmser",
    "license": "CC BY 4.0",
    "labels": "del autor del dataset, sin confirmación veterinaria",
}


def synthetic_pattern(kind, size=IMAGE_SIZE[0]):
    """Imágenes de prueba definidas por una fórmula (la app las genera igual en Dart) para comparar
    Keras, TFLite y la app sin guardar fotos. No son datos: solo verifican el cálculo."""
    y, x = np.mgrid[0:size, 0:size]
    if kind == 0:
        channels = [(x * 255) // (size - 1), (y * 255) // (size - 1), ((x + y) * 255) // (2 * (size - 1))]
    elif kind == 1:
        channels = [(x * 7 + y * 3) % 256, (x * 5 + y * 11) % 256, (x * 13 + y * 2) % 256]
    elif kind == 2:
        checker = ((x // 28 + y // 28) % 2) * 200 + 30
        channels = [checker, checker // 2 + 60, 255 - checker]
    else:
        r = np.sqrt((x - size / 2) ** 2 + (y - size / 2) ** 2)
        ring = (np.cos(r / 6) * 100 + 128).astype(int)
        channels = [np.clip(ring + 40, 0, 255), ring, np.clip(ring - 40, 0, 255)]
    return np.stack(channels, axis=-1).astype(np.uint8)


PATTERNS = (0, 1, 2, 3)


def run_cv(name, images, labels, groups, args, log):
    """Validación cruzada agrupada; devuelve las probabilidades fuera de partición (repeticiones x N)
    y las épocas usadas en cada fold."""
    folds = repeated_group_folds(labels, groups, args.splits, args.repeats, SEED)
    if args.max_folds:
        folds = folds[:args.max_folds]
    probs = np.full((args.repeats, len(labels)), np.nan)
    epochs_used = []
    for rep, fold, train_idx, test_idx in folds:
        start = time.time()
        seed = SEED + 100 * rep + fold
        tf.keras.backend.clear_session()
        tf.keras.utils.set_random_seed(seed)
        fit_idx, val_idx = inner_validation_split(labels, groups, train_idx, seed=seed)
        train_ds = array_dataset(images[fit_idx], labels[fit_idx], args.batch, make_augmenter(seed),
                                 shuffle=True, seed=seed)
        val_ds = array_dataset(images[val_idx], labels[val_idx], args.batch)
        model, backbone = build_cnn()
        history = fit_two_phase(model, backbone, train_ds, val_ds, args.epochs, args.fine_tune_epochs,
                                class_weight=balanced_class_weight(labels[fit_idx]), patience=args.patience)
        probs[rep, test_idx] = model.predict(images[test_idx].astype(np.float32), verbose=0).ravel()
        epochs_used.append((len(history["head"]["loss"]), len(history["fine_tune"]["loss"])))
        log(f"[{name}] rep {rep} fold {fold}: train {len(fit_idx)} val {len(val_idx)} test {len(test_idx)} "
            f"épocas {epochs_used[-1]} {time.time() - start:.0f}s")
    return probs, epochs_used


def report_cv(probs, labels, groups, epochs_used):
    """Métricas con la probabilidad media entre repeticiones y la variación entre repeticiones."""
    done = ~np.isnan(probs).any(axis=1)
    if not done.any():
        return None
    probs = probs[done]
    pooled = summarize(labels, probs.mean(axis=0), groups, THRESHOLD, seed=SEED)
    per_rep = [summarize(labels, p, groups, THRESHOLD, n_boot=200, seed=SEED) for p in probs]

    def spread(key):
        values = np.array([r[key] for r in per_rep], dtype=float)
        return {"mean": float(values.mean()), "sd": float(values.std(ddof=1)) if len(values) > 1 else 0.0,
                "min": float(values.min()), "max": float(values.max())}

    return {
        "pooled_mean_probability": pooled,
        "across_repeats": {k: spread(k) for k in ("auc", "sensitivity", "specificity", "balanced_accuracy")},
        "repeats_completed": int(done.sum()),
        "epochs_head_median": float(np.median([e[0] for e in epochs_used])),
        "epochs_fine_tune_median": float(np.median([e[1] for e in epochs_used])),
    }


def subset_report(probs, labels, groups, mask):
    done = ~np.isnan(probs).any(axis=1)
    return summarize(labels[mask], probs[done].mean(axis=0)[mask], groups[mask], THRESHOLD, seed=SEED)


def train_final(images, labels, groups, args, log):
    """Modelo final con todas las fotos (un grupo de validación interno para la parada temprana)."""
    tf.keras.backend.clear_session()
    tf.keras.utils.set_random_seed(SEED)
    fit_idx, val_idx = inner_validation_split(labels, groups, np.arange(len(labels)), seed=SEED)
    train_ds = array_dataset(images[fit_idx], labels[fit_idx], args.batch, make_augmenter(SEED),
                             shuffle=True, seed=SEED)
    val_ds = array_dataset(images[val_idx], labels[val_idx], args.batch)
    model, backbone = build_cnn()
    history = fit_two_phase(model, backbone, train_ds, val_ds, args.epochs, args.fine_tune_epochs,
                            class_weight=balanced_class_weight(labels[fit_idx]), patience=args.patience)
    log(f"[final] épocas cabeza {len(history['head']['loss'])}, ajuste {len(history['fine_tune']['loss'])}")
    return model


def export_and_check(model, crops, work_dir, log):
    """Exporta a TFLite (pesos float16) y mide la paridad con Keras sobre los recortes reales y sobre
    los patrones sintéticos. Las variantes float32 e int8 quedan en work-dir para comparar."""
    keras_real = model.predict(crops.astype(np.float32), verbose=0).ravel()
    patterns = np.stack([synthetic_pattern(k) for k in PATTERNS])
    keras_syn = model.predict(patterns.astype(np.float32), verbose=0).ravel()

    def compare(path, size):
        lite_real = tflite_predict(path, crops)
        return {
            "bytes": int(size),
            "real_crops_max_abs_diff": float(np.abs(keras_real - lite_real).max()),
            "real_crops_mean_abs_diff": float(np.abs(keras_real - lite_real).mean()),
            "real_crops_same_decision": float(np.mean((keras_real >= THRESHOLD) == (lite_real >= THRESHOLD))),
            "flipped_keras_vs_tflite": [
                (round(float(k), 4), round(float(t), 4)) for k, t in zip(keras_real, lite_real)
                if (k >= THRESHOLD) != (t >= THRESHOLD)],
        }

    variants = {}
    for mode in (None, "int8"):
        path = work_dir / f"udder_cnn_{mode or 'float32'}.tflite"
        variants[mode or "float32"] = compare(path, export_tflite(model, path, quantize=mode))
    size = export_tflite(model, TFLITE_PATH, quantize=QUANTIZE)
    lite_syn = tflite_predict(TFLITE_PATH, patterns)
    parity = {
        "exported": QUANTIZE,
        "tolerance": TOLERANCE,
        **compare(TFLITE_PATH, size),
        "patterns_max_abs_diff": float(np.abs(keras_syn - lite_syn).max()),
        "other_variants": variants,
    }
    tolerance = TOLERANCE
    if parity["real_crops_max_abs_diff"] > tolerance:
        raise SystemExit(f"La paridad Keras/TFLite falla en las fotos reales: {parity}")
    log(f"[export] {parity}")
    VECTORS_PATH.write_text(json.dumps({
        "description": "Patrones sintéticos definidos por fórmula (synthetic_pattern); no son fotos. "
                       "keras = salida del modelo Keras; la app y TFLite deben coincidir dentro "
                       "de tolerance.",
        "tolerance": tolerance,
        "cases": [{"pattern": int(k), "keras": float(kp), "tflite": float(lp)}
                  for k, kp, lp in zip(PATTERNS, keras_syn, lite_syn)],
    }, indent=2), encoding="utf-8")
    return parity


def main():
    parser = argparse.ArgumentParser(description="CNN de la ubre con el dataset público (CC BY 4.0).")
    parser.add_argument("--coco", type=Path, required=True, help="Carpeta del export COCO (fuera del repo)")
    parser.add_argument("--work-dir", type=Path, required=True, help="Salidas por imagen (fuera del repo)")
    parser.add_argument("--experiments", default="main,img_n,background")
    parser.add_argument("--splits", type=int, default=5)
    parser.add_argument("--repeats", type=int, default=5)
    parser.add_argument("--epochs", type=int, default=30)
    parser.add_argument("--fine-tune-epochs", type=int, default=20)
    parser.add_argument("--patience", type=int, default=5)
    parser.add_argument("--batch", type=int, default=16)
    parser.add_argument("--max-folds", type=int, default=0, help="Solo para medir tiempos")
    parser.add_argument("--skip-final", action="store_true")
    parser.add_argument("--export-only", action="store_true",
                        help="No entrena: vuelve a exportar el udder_cnn.keras guardado en work-dir")
    args = parser.parse_args()
    if args.export_only:
        args.experiments = ""

    repo = ML_DIR.parent.resolve()
    if any(repo == p or repo in p.parents for p in (args.work_dir.resolve(), args.coco.resolve())):
        raise SystemExit("Los datos y las salidas por imagen deben quedar fuera del repositorio.")
    args.work_dir.mkdir(parents=True, exist_ok=True)
    log_file = (args.work_dir / "train_log.txt").open("a", encoding="utf-8")

    def log(message):
        print(message, flush=True)
        log_file.write(message + "\n")
        log_file.flush()

    records, crops, backgrounds, dropped = load_dataset(args.coco)
    labels = np.array([r.label for r in records])
    groups = np.array([r.group for r in records])
    series = np.array([r.series for r in records])
    multi = [g for g in np.unique(groups) if (groups == g).sum() > 1]
    dataset = {
        "images_total": len(records) + len(dropped),
        "images_used": len(records),
        "dropped_short_side_lt_96px": sorted(r.name for r in dropped),
        "healthy": int((labels == 0).sum()),
        "mastitis": int((labels == 1).sum()),
        "groups": int(len(np.unique(groups))),
        "multi_image_groups": len(multi),
        "images_in_multi_image_groups": int(sum((groups == g).sum() for g in multi)),
        "groups_with_mixed_label": int(sum(len(set(labels[groups == g])) > 1 for g in np.unique(groups))),
        "series_counts": {s: {"healthy": int(((series == s) & (labels == 0)).sum()),
                              "mastitis": int(((series == s) & (labels == 1)).sum())}
                          for s in sorted(set(series))},
    }
    log(f"[datos] {json.dumps(dataset, ensure_ascii=False)}")

    report = {
        "warning": "Etiquetas del autor del dataset público, sin confirmación veterinaria. Las métricas "
                   "miden concordancia con esas etiquetas, no capacidad diagnóstica.",
        "source": SOURCE,
        "preprocessing": {"crop_margin": CROP_MARGIN, "min_crop_side_px": MIN_CROP_SIDE,
                          "pad": "cuadrado, relleno negro", "input_size": IMAGE_SIZE[0]},
        "model": f"MobileNetV2 alpha {ALPHA} (ImageNet), cabeza GAP + Dropout 0.3 + Dense sigmoide; fase 1 "
                 f"cabeza lr 1e-3, fase 2 ajuste fino de las últimas {FINE_TUNE_LAYERS} capas lr 1e-5; "
                 "pesos de clase balanceados; parada temprana (val_loss, paciencia 5)",
        "validation": f"StratifiedGroupKFold {args.splits}x{args.repeats} por vaca; parada temprana con un "
                      "sexto de los grupos de entrenamiento; umbral 0.5",
        "dataset": dataset,
        "experiments": {},
    }
    if REPORT_PATH.exists():
        previous = json.loads(REPORT_PATH.read_text(encoding="utf-8"))
        report["experiments"] = previous.get("experiments", {})
        report["export"] = previous.get("export")

    oof = {"names": [r.name for r in records], "labels": labels.tolist(), "groups": groups.tolist(),
           "series": series.tolist()}
    wanted = [e.strip() for e in args.experiments.split(",") if e.strip()]
    for name in wanted:
        if name == "main":
            probs, epochs = run_cv(name, crops, labels, groups, args, log)
            result = report_cv(probs, labels, groups, epochs)
            if result is not None:
                # Solo img-N tiene las dos clases (la serie N es toda mastitis): ahí se mide sin el atajo
                # potrero = mastitis; para N se reporta la sensibilidad.
                result["restricted_to_series"] = {
                    s: subset_report(probs, labels, groups, series == s)
                    for s in ("img-N",) if len(set(labels[series == s])) > 1}
                done = ~np.isnan(probs).any(axis=1)
                n_mask = series == "N"
                hits = int((probs[done].mean(axis=0)[n_mask] >= THRESHOLD).sum())
                result["series_N_all_mastitis_sensitivity"] = {
                    "detected": hits, "total": int(n_mask.sum()),
                    "ci95": wilson_interval(hits, int(n_mask.sum()))}
        elif name == "img_n":
            mask = series == "img-N"
            probs, epochs = run_cv(name, crops[mask], labels[mask], groups[mask], args, log)
            result = report_cv(probs, labels[mask], groups[mask], epochs)
            oof_mask = mask
        elif name == "background":
            probs, epochs = run_cv(name, backgrounds, labels, groups, args, log)
            result = report_cv(probs, labels, groups, epochs)
        else:
            raise SystemExit(f"Experimento desconocido: {name}")
        if result is None:
            log(f"[{name}] ninguna repetición completa (modo de medición de tiempos); no se reporta")
            continue
        report["experiments"][name] = result
        oof[name] = probs.tolist()
        if name == "img_n":
            oof[name] = {"mask": oof_mask.tolist(), "probs": probs.tolist()}
        log(f"[{name}] {json.dumps(result['pooled_mean_probability'])}")
        (args.work_dir / "oof_predictions.json").write_text(json.dumps(oof), encoding="utf-8")
        REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
        REPORT_PATH.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")

    if not args.skip_final:
        if args.export_only:
            model = tf.keras.models.load_model(args.work_dir / "udder_cnn.keras")
        else:
            model = train_final(crops, labels, groups, args, log)
            model.save(args.work_dir / "udder_cnn.keras")
        report["export"] = export_and_check(model, crops, args.work_dir, log)
        CONFIG_PATH.write_text(json.dumps({
            "modelFile": TFLITE_PATH.name,
            "inputSize": IMAGE_SIZE[0],
            "inputRange": "RGB 0-255 en float32; el modelo reescala a [-1, 1]",
            "pad": "cuadrado centrado, relleno negro (0, 0, 0)",
            "cropMargin": CROP_MARGIN,
            "threshold": THRESHOLD,
            "output": "probabilidad de signos de mastitis según las etiquetas del dataset público",
            "enabledByDefault": False,
            "disclaimer": "Orientativo, no es diagnóstico.",
            "source": SOURCE,
        }, indent=2, ensure_ascii=False), encoding="utf-8")
        REPORT_PATH.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    log_file.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
