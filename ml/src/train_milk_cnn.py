"""Evaluación de un clasificador de pozo de leche normal o anormal (sangre, grumos o aguada).

NO se integra en la app normal: el modelo final solo entra, como experimento, en el APK de
demostración (models/milk_cnn.tflite, ver src/export_milk_vectors.py). Datos y modelos por fold quedan
FUERA del repositorio (--work-dir); aquí solo quedan el informe (reports/milk_cnn.json) y las figuras
(informes/). Ver ml/README.md.

    python src/train_milk_cnn.py --coco "C:/.../Data/roboflow_leche/Mastitis dataset.v3i.coco" \
                                 --work-dir "C:/.../Data/agrovet_work/milk_cnn"

Pasos (todo con StratifiedGroupKFold 5x5 por grupo de pHash y sesión PXL):
1. MobileNetV2 (alpha 0.35) y MobileNetV3-Small (alpha 0.75), entrenadas por etapas: primero solo la
   cabeza con la red congelada, después se afinan las últimas capas con aumento de datos.
2. Control de sesgo: la misma red con la foto entera y todos los pozos tapados (solo contexto).
3. Sesión PXL fuera: entrena sin las fotos de teléfono y evalúa solo en ellas.
4. Con los modelos de la repetición 0 (cada pozo evaluado por el modelo que no lo vio): Grad-CAM y
   robustez a luz, desenfoque, rotación y JPEG.
5. Modelo final con todos los pozos, exportado a TFLite float16: tamaño, latencia y diferencia con
   Keras.
El avance se guarda en --work-dir después de cada fold: si se corta, se retoma donde quedó.
"""

from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

import numpy as np
import tensorflow as tf
from PIL import Image

from cnn_evaluation import balanced_class_weight, inner_validation_split, repeated_group_folds, summarize
from milk_data import (
    DEGRADATIONS,
    IMAGE_SIZE,
    MilkImage,
    Wells,
    build_wells,
    degrade,
    group_images,
    label_conflicts,
    load_images,
    pxl_sessions,
)
from milk_evaluation import calibration_bins, full_report, grade_confusion, paired_auc_difference
from train_cnn import array_dataset, export_tflite, make_augmenter

ML_DIR = Path(__file__).resolve().parents[1]
REPORT_PATH = ML_DIR / "reports" / "milk_cnn.json"
FIGURES_DIR = ML_DIR / "informes"
SEED = 42
THRESHOLD = 0.5
ARCHITECTURES = {
    # nombre: (constructor de keras.applications, alpha, capas finales que se afinan)
    "mobilenet_v2": ("MobileNetV2", 0.35, 30),
    "mobilenet_v3_small": ("MobileNetV3Small", 0.75, 30),
}
SOURCE = {
    "name": "Mastitis dataset v3 (Roboflow Universe, usuario abdurrehman4198)",
    "url": "https://universe.roboflow.com/abdurrehman4198-gmail-com/mastitis-dataset",
    "license": "CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)",
}


# ---------------------------------------------------------------- modelo y entrenamiento por etapas


def build_model(
    arch: str, size: int = IMAGE_SIZE, weights: str | None = "imagenet", dropout: float = 0.3
) -> tuple[tf.keras.Model, tf.keras.Model]:
    """Red preentrenada congelada + cabeza binaria. Entrada: RGB 0-255 en float32; el reescalado a
    [-1, 1] va dentro del modelo (las dos redes esperan ese rango)."""
    constructor, alpha, _ = ARCHITECTURES[arch]
    inputs = tf.keras.Input(shape=(size, size, 3), name="image")
    x = tf.keras.layers.Rescaling(1 / 127.5, offset=-1, name="to_minus1_1")(inputs)
    kwargs = {"include_preprocessing": False} if arch == "mobilenet_v3_small" else {}
    backbone = getattr(tf.keras.applications, constructor)(
        input_shape=(size, size, 3), include_top=False, weights=weights, alpha=alpha, **kwargs
    )
    backbone.trainable = False
    # training=False: la normalización por lotes queda en modo inferencia también al afinar
    x = backbone(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D(name="pool")(x)
    x = tf.keras.layers.Dropout(dropout, name="dropout")(x)
    outputs = tf.keras.layers.Dense(1, activation="sigmoid", name="abnormal_probability")(x)
    return tf.keras.Model(inputs, outputs, name=f"milk_{arch}"), backbone


def _stopper(patience: int) -> list:
    return [
        tf.keras.callbacks.EarlyStopping(monitor="val_loss", patience=patience, restore_best_weights=True)
    ]


def fit_staged(
    model: tf.keras.Model,
    backbone: tf.keras.Model,
    arch: str,
    images: np.ndarray,
    labels: np.ndarray,
    fit_idx: np.ndarray,
    val_idx: np.ndarray,
    seed: int,
    head_epochs: int = 100,
    tune_epochs: int = 15,
    batch: int = 32,
    predict_idx: np.ndarray | None = None,
) -> dict:
    """Etapa 1: solo la cabeza, con la red congelada. Las características de la red se calculan una
    vez (sin aumento) y la cabeza se entrena sobre ellas: es lo mismo que congelar y mucho más rápido.
    Etapa 2: se descongelan las últimas capas y se afina todo con aumento de datos y lr 1e-5.
    Devuelve las épocas usadas y, si se pide, las probabilidades de predict_idx tras cada etapa."""
    weights = balanced_class_weight(labels[fit_idx])
    pool = tf.keras.Model(model.input, model.get_layer("pool").output)
    feats_fit = pool.predict(images[fit_idx].astype(np.float32), batch_size=64, verbose=0)
    feats_val = pool.predict(images[val_idx].astype(np.float32), batch_size=64, verbose=0)
    head_in = tf.keras.Input(shape=feats_fit.shape[1:])
    head_out = model.get_layer("abnormal_probability")(model.get_layer("dropout")(head_in))
    head = tf.keras.Model(head_in, head_out)
    head.compile(optimizer=tf.keras.optimizers.Adam(1e-3), loss="binary_crossentropy")
    stage1 = head.fit(
        feats_fit,
        labels[fit_idx].astype(np.float32),
        validation_data=(feats_val, labels[val_idx]),
        epochs=head_epochs,
        batch_size=batch,
        class_weight=weights,
        callbacks=_stopper(10),
        verbose=0,
    )
    result: dict = {"head_epochs": len(stage1.history["loss"])}
    if predict_idx is not None:
        result["frozen"] = model.predict(
            images[predict_idx].astype(np.float32), batch_size=64, verbose=0
        ).ravel()

    backbone.trainable = True
    for layer in backbone.layers[: -ARCHITECTURES[arch][2]]:
        layer.trainable = False
    model.compile(optimizer=tf.keras.optimizers.Adam(1e-5), loss="binary_crossentropy")
    train_ds = array_dataset(
        images[fit_idx], labels[fit_idx], batch, make_augmenter(seed), shuffle=True, seed=seed
    )
    val_ds = array_dataset(images[val_idx], labels[val_idx], batch)
    stage2 = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=tune_epochs,
        class_weight=weights,
        callbacks=_stopper(3),
        verbose=0,
    )
    result["tune_epochs"] = len(stage2.history["loss"])
    if predict_idx is not None:
        result["tuned"] = model.predict(
            images[predict_idx].astype(np.float32), batch_size=64, verbose=0
        ).ravel()
    return result


def train_on(
    arch: str,
    images: np.ndarray,
    labels: np.ndarray,
    groups: np.ndarray,
    train_idx: np.ndarray,
    test_idx: np.ndarray,
    seed: int,
    args: argparse.Namespace,
) -> tuple[tf.keras.Model, dict]:
    tf.keras.backend.clear_session()
    tf.keras.utils.set_random_seed(seed)
    fit_idx, val_idx = inner_validation_split(labels, groups, train_idx, seed=seed)
    # --weights none solo para la prueba de humo: así no descarga los pesos de ImageNet
    weights = None if args.weights == "none" else args.weights
    model, backbone = build_model(arch, args.size, weights=weights)
    result = fit_staged(
        model,
        backbone,
        arch,
        images,
        labels,
        fit_idx,
        val_idx,
        seed,
        args.head_epochs,
        args.tune_epochs,
        args.batch,
        predict_idx=test_idx,
    )
    return model, result


# ---------------------------------------------------------------- validación cruzada con reanudación


def run_cv(
    name: str,
    arch: str,
    images: np.ndarray,
    wells: Wells,
    args: argparse.Namespace,
    work_dir: Path,
    keep_models: bool,
) -> dict:
    """Validación cruzada agrupada. Guarda después de cada fold las probabilidades fuera de muestra
    (etapa congelada y afinada) en work_dir/<name>.json; los modelos de la repetición 0, si se pide."""
    state_path = work_dir / f"{name}.json"
    n = len(wells.labels)
    state: dict = (
        json.loads(state_path.read_text(encoding="utf-8"))
        if state_path.exists()
        else {
            "frozen": [[None] * n for _ in range(args.repeats)],
            "tuned": [[None] * n for _ in range(args.repeats)],
            "done": [],
            "epochs": [],
        }
    )
    folds = repeated_group_folds(wells.labels, wells.groups, args.splits, args.repeats, SEED)
    for rep, fold, train_idx, test_idx in folds:
        key = f"{rep}-{fold}"
        if key in state["done"]:
            continue
        start = time.time()
        model, result = train_on(
            arch, images, wells.labels, wells.groups, train_idx, test_idx, SEED + 100 * rep + fold, args
        )
        for stage in ("frozen", "tuned"):
            for i, p in zip(test_idx.tolist(), result[stage].tolist()):
                state[stage][rep][i] = p
        state["done"].append(key)
        state["epochs"].append([result["head_epochs"], result["tune_epochs"]])
        if keep_models and rep == 0:
            model.save(work_dir / f"{name}_fold{fold}.keras")
        state_path.write_text(json.dumps(state), encoding="utf-8")
        print(
            f"[{name}] rep {rep} fold {fold}: {time.time() - start:.0f} s, épocas {result['head_epochs']}"
            f"+{result['tune_epochs']}",
            flush=True,
        )
    state["folds_rep0"] = [test_idx.tolist() for rep, _, _, test_idx in folds if rep == 0]
    return state


def cv_report(state: dict, wells: Wells, args: argparse.Namespace) -> dict:
    tuned = np.array(state["tuned"], dtype=float)
    frozen = np.array(state["frozen"], dtype=float)
    mean = tuned.mean(axis=0)
    per_rep = [
        summarize(wells.labels, p, wells.groups, THRESHOLD, n_boot=200, seed=SEED)["auc"] for p in tuned
    ]
    frozen_rep = [
        summarize(wells.labels, p, wells.groups, THRESHOLD, n_boot=200, seed=SEED)["auc"] for p in frozen
    ]
    # Calibración con cada predicción fuera de muestra (una por pozo y repetición), no con el promedio
    stacked_labels = np.tile(wells.labels, args.repeats)
    stacked = tuned.ravel()
    report = full_report(wells.labels, mean, wells.groups, THRESHOLD, n_boot=args.n_boot, seed=SEED)
    report.update(
        {
            "auc_by_repeat": {
                "mean": float(np.mean(per_rep)),
                "min": float(np.min(per_rep)),
                "max": float(np.max(per_rep)),
            },
            "auc_frozen_stage_by_repeat": {
                "mean": float(np.mean(frozen_rep)),
                "min": float(np.min(frozen_rep)),
                "max": float(np.max(frozen_rep)),
            },
            "calibration_all_predictions": {
                "ece": full_report(
                    stacked_labels,
                    stacked,
                    np.tile(wells.groups, args.repeats),
                    THRESHOLD,
                    n_boot=50,
                    seed=SEED,
                )["ece"],
                "bins": calibration_bins(stacked_labels, stacked),
            },
            "confusion_by_grade": grade_confusion(wells.grades, (mean >= THRESHOLD).astype(int)),
            "epochs_head_tune_mean": np.mean(np.array(state["epochs"]), axis=0).tolist(),
        }
    )
    return report


# ---------------------------------------------------------------- Grad-CAM y robustez


def grad_cam(model: tf.keras.Model, images: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Mapas Grad-CAM (N, h, w) en [0, 1] sobre la última capa de la red, hacia la clase predicha,
    y las probabilidades. La cabeza es pooling + densa, así que se recalcula a mano."""
    backbone = next(layer for layer in model.layers if isinstance(layer, tf.keras.Model))
    rescale = model.get_layer("to_minus1_1")
    dense = model.get_layer("abnormal_probability")
    x = rescale(tf.convert_to_tensor(images, dtype=tf.float32))
    with tf.GradientTape() as tape:
        conv = backbone(x, training=False)
        tape.watch(conv)
        logit = tf.matmul(tf.reduce_mean(conv, axis=(1, 2)), dense.kernel) + dense.bias
        prob = tf.sigmoid(logit)[:, 0]
        # Hacia la clase predicha: anormal si p >= 0,5; normal en otro caso
        target = tf.where(prob >= THRESHOLD, logit[:, 0], -logit[:, 0])
    grads = tape.gradient(target, conv)
    weights = tf.reduce_mean(grads, axis=(1, 2), keepdims=True)
    cam = tf.nn.relu(tf.reduce_sum(weights * conv, axis=-1)).numpy()
    cam /= np.maximum(cam.max(axis=(1, 2), keepdims=True), 1e-8)
    return cam, prob.numpy()


def overlay(image: np.ndarray, cam: np.ndarray) -> np.ndarray:
    import matplotlib

    heat = (
        np.asarray(
            Image.fromarray(np.uint8(cam * 255)).resize(image.shape[:2][::-1], Image.Resampling.BILINEAR),
            dtype=np.float64,
        )
        / 255
    )
    colored = matplotlib.colormaps["jet"](heat)[..., :3] * 255
    return np.asarray(0.55 * image + 0.45 * colored, dtype=np.uint8)


def save_gradcam_grid(path: Path, title: str, items: list[tuple[np.ndarray, np.ndarray, str]]) -> None:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    cols = max(1, len(items))
    fig, axes = plt.subplots(2, cols, figsize=(2.2 * cols, 4.8), squeeze=False)
    for c, (image, cam, label) in enumerate(items):
        axes[0, c].imshow(image)
        axes[0, c].set_title(label, fontsize=7)
        axes[1, c].imshow(overlay(image, cam))
    for ax in axes.ravel():
        ax.axis("off")
    fig.suptitle(title, fontsize=9)
    fig.text(
        0.5,
        0.01,
        "Imágenes: Mastitis dataset v3, Roboflow Universe (abdurrehman4198), CC BY 4.0",
        ha="center",
        fontsize=6,
    )
    fig.tight_layout(rect=(0, 0.03, 1, 0.95))
    fig.savefig(path, dpi=110)
    plt.close(fig)


def gradcam_examples(name: str, wells: Wells, state: dict, work_dir: Path, per_category: int = 6) -> dict:
    """Aciertos y errores de la repetición 0, cada pozo explicado por el modelo que no lo vio."""
    rep0 = np.array(state["tuned"][0], dtype=float)
    pred = (rep0 >= THRESHOLD).astype(int)
    categories = {
        "verdaderos_positivos": (wells.labels == 1) & (pred == 1),
        "verdaderos_negativos": (wells.labels == 0) & (pred == 0),
        "falsos_positivos": (wells.labels == 0) & (pred == 1),
        "falsos_negativos": (wells.labels == 1) & (pred == 0),
    }
    fold_of = np.empty(len(wells.labels), dtype=int)
    for fold, test_idx in enumerate(state["folds_rep0"]):
        fold_of[test_idx] = fold
    rng = np.random.default_rng(SEED)
    counts, files = {}, {}
    for category, mask in categories.items():
        idx = np.flatnonzero(mask)
        counts[category] = int(len(idx))
        if not len(idx):
            continue
        # Errores: los más seguros (los más graves); aciertos: al azar
        if category.startswith("falsos"):
            chosen = idx[np.argsort(-np.abs(rep0[idx] - 0.5))][:per_category]
        else:
            chosen = rng.choice(idx, size=min(per_category, len(idx)), replace=False)
        items = []
        for i in chosen:
            model = tf.keras.models.load_model(work_dir / f"{name}_fold{fold_of[i]}.keras")
            cam, prob = grad_cam(model, wells.crops[i : i + 1].astype(np.float32))
            items.append((wells.crops[i], cam[0], f"{wells.grades[i].replace(' Milk', '')}\np={prob[0]:.2f}"))
        path = FIGURES_DIR / f"gradcam_{name}_{category}.png"
        save_gradcam_grid(
            path, f"{name}: {category.replace('_', ' ')} (rep. 0, modelo que no vio el pozo)", items
        )
        files[category] = str(path.relative_to(ML_DIR)).replace("\\", "/")
    return {"counts_rep0": counts, "figures": files}


def robustness(name: str, wells: Wells, state: dict, work_dir: Path) -> list[dict]:
    """Cada pozo de la repetición 0, degradado y evaluado por el modelo de su fold."""
    models = [
        tf.keras.models.load_model(work_dir / f"{name}_fold{k}.keras")
        for k in range(len(state["folds_rep0"]))
    ]

    def predict(transform) -> np.ndarray:
        probs = np.empty(len(wells.labels))
        for model, test_idx in zip(models, state["folds_rep0"]):
            images = transform(wells.crops[test_idx]).astype(np.float32)
            probs[test_idx] = model.predict(images, batch_size=64, verbose=0).ravel()
        return probs

    rows = []
    clean = summarize(wells.labels, predict(lambda x: x), wells.groups, THRESHOLD, n_boot=500, seed=SEED)
    rows.append(
        {
            "degradation": "ninguna",
            "level": None,
            "auc": clean["auc"],
            "sensitivity": clean["sensitivity"],
            "specificity": clean["specificity"],
            "delta_auc": 0.0,
        }
    )
    for kind, (_, levels) in DEGRADATIONS.items():
        for level in levels:
            result = summarize(
                wells.labels,
                predict(lambda x, k=kind, v=level: degrade(x, k, v)),
                wells.groups,
                THRESHOLD,
                n_boot=500,
                seed=SEED,
            )
            rows.append(
                {
                    "degradation": kind,
                    "level": level,
                    "auc": result["auc"],
                    "sensitivity": result["sensitivity"],
                    "specificity": result["specificity"],
                    "delta_auc": result["auc"] - clean["auc"],
                }
            )
            print(f"[robustez {name}] {kind} {level}: AUC {result['auc']:.3f}", flush=True)
    return rows


def save_calibration_plot(reports: dict[str, dict]) -> str:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(4.2, 4.2))
    ax.plot([0, 1], [0, 1], linestyle="--", color="grey", linewidth=1, label="calibración perfecta")
    for name, report in reports.items():
        bins = report["calibration_all_predictions"]["bins"]
        ax.plot(
            [b["mean_probability"] for b in bins],
            [b["fraction_abnormal"] for b in bins],
            marker="o",
            label=f"{name} (ECE {report['calibration_all_predictions']['ece']:.3f})",
        )
    ax.set_xlabel("Probabilidad predicha de leche anormal")
    ax.set_ylabel("Fracción real de pozos anormales")
    ax.set_title("Curva de calibración (fuera de muestra, 5x5)", fontsize=9)
    ax.legend(fontsize=7)
    fig.tight_layout()
    path = FIGURES_DIR / "calibracion.png"
    fig.savefig(path, dpi=120)
    plt.close(fig)
    return str(path.relative_to(ML_DIR)).replace("\\", "/")


# ---------------------------------------------------------------- exportación


def tflite_latency(tflite_path: Path, image: np.ndarray, threads: int, runs: int = 200) -> float:
    interpreter = tf.lite.Interpreter(model_path=str(tflite_path), num_threads=threads)
    interpreter.allocate_tensors()
    inp = interpreter.get_input_details()[0]["index"]
    interpreter.set_tensor(inp, image[None].astype(np.float32))
    for _ in range(20):
        interpreter.invoke()
    times = []
    for _ in range(runs):
        start = time.perf_counter()
        interpreter.invoke()
        times.append((time.perf_counter() - start) * 1000)
    return float(np.median(times))


def tflite_probabilities(tflite_path: Path, images: np.ndarray) -> np.ndarray:
    interpreter = tf.lite.Interpreter(model_path=str(tflite_path))
    interpreter.allocate_tensors()
    inp = interpreter.get_input_details()[0]["index"]
    out = interpreter.get_output_details()[0]["index"]
    probs = []
    for image in images.astype(np.float32):
        interpreter.set_tensor(inp, image[None])
        interpreter.invoke()
        probs.append(float(interpreter.get_tensor(out)[0][0]))
    return np.array(probs)


def export_final(arch: str, wells: Wells, args: argparse.Namespace, work_dir: Path) -> dict:
    """Modelo final con todos los pozos (la validación interna solo decide cuándo parar) y TFLite
    float16. Las métricas de calidad son las de la validación cruzada, no las de este modelo."""
    all_idx = np.arange(len(wells.labels))
    model, _ = train_on(arch, wells.crops, wells.labels, wells.groups, all_idx, all_idx[:1], SEED, args)
    keras_path = work_dir / f"final_{arch}.keras"
    model.save(keras_path)
    tflite_path = work_dir / f"milk_{arch}_float16.tflite"
    size = export_tflite(model, tflite_path, quantize="float16")
    keras_probs = model.predict(wells.crops.astype(np.float32), batch_size=64, verbose=0).ravel()
    lite_probs = tflite_probabilities(tflite_path, wells.crops)
    diff = np.abs(keras_probs - lite_probs)
    changed = int(((keras_probs >= THRESHOLD) != (lite_probs >= THRESHOLD)).sum())
    return {
        "architecture": arch,
        "input": f"{args.size}x{args.size} RGB 0-255 float32",
        "quantization": "float16",
        "tflite_bytes": int(size),
        "keras_params": int(model.count_params()),
        "latency_ms_median_pc_cpu": {
            "1_thread": tflite_latency(tflite_path, wells.crops[0], 1),
            "4_threads": tflite_latency(tflite_path, wells.crops[0], 4),
        },
        "keras_vs_tflite": {
            "max_abs_diff": float(diff.max()),
            "mean_abs_diff": float(diff.mean()),
            "decisions_changed": changed,
            "wells": int(len(diff)),
        },
        "note": "Latencia medida en el CPU del PC de desarrollo con el intérprete de TFLite, "
        "no en un celular.",
    }


# ---------------------------------------------------------------- programa


def dataset_summary(
    images: list[MilkImage], pils: list[Image.Image], image_groups: list[int], wells: Wells
) -> dict:
    spanning = sum(
        1 for g in set(image_groups) if len({im.split for im, gg in zip(images, image_groups) if gg == g}) > 1
    )
    per_group = {g: set(wells.labels[wells.groups == g].tolist()) for g in set(wells.groups.tolist())}
    return {
        "images": len(images),
        "wells": int(len(wells.labels)),
        "normal": int((wells.labels == 0).sum()),
        "abnormal": int((wells.labels == 1).sum()),
        "wells_by_grade": {g: int((wells.grades == g).sum()) for g in sorted(set(wells.grades.tolist()))},
        "wells_by_source": {s: int((wells.sources == s).sum()) for s in sorted(set(wells.sources.tolist()))},
        "groups": len(set(image_groups)),
        "groups_spanning_roboflow_splits": spanning,
        "groups_with_single_class": sum(1 for v in per_group.values() if len(v) == 1),
        "largest_group_wells": int(np.bincount(wells.groups).max()),
        "label_conflicts_near_identical_frames": len(label_conflicts(images, pils)),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Evalúa el clasificador de pozo de leche normal o anormal.")
    parser.add_argument("--coco", type=Path, required=True)
    parser.add_argument("--work-dir", type=Path, required=True)
    parser.add_argument("--splits", type=int, default=5)
    parser.add_argument("--repeats", type=int, default=5)
    parser.add_argument("--size", type=int, default=IMAGE_SIZE)
    parser.add_argument("--head-epochs", type=int, default=100)
    parser.add_argument("--tune-epochs", type=int, default=15)
    parser.add_argument("--batch", type=int, default=32)
    parser.add_argument("--n-boot", type=int, default=2000)
    parser.add_argument("--weights", choices=("imagenet", "none"), default="imagenet")
    # Por defecto las dos redes; la prueba de punta a punta corre solo una para no tardar
    parser.add_argument("--archs", nargs="+", choices=list(ARCHITECTURES), default=list(ARCHITECTURES))
    args = parser.parse_args()
    repo = ML_DIR.parent.resolve()
    if any(repo == p or repo in p.parents for p in (args.work_dir.resolve(), args.coco.resolve())):
        raise SystemExit("Los datos y los modelos por fold deben quedar fuera del repositorio.")
    args.work_dir.mkdir(parents=True, exist_ok=True)
    FIGURES_DIR.mkdir(parents=True, exist_ok=True)

    images = load_images(args.coco)
    pils = [Image.open(im.path).convert("RGB") for im in images]
    image_groups = group_images(pils, pxl_sessions([im.name for im in images]))
    wells = build_wells(images, pils, image_groups, args.size)
    dataset = dataset_summary(images, pils, image_groups, wells)
    print("[datos]", json.dumps(dataset, ensure_ascii=False), flush=True)

    reports, states = {}, {}
    names = list(args.archs)
    for arch in names:
        states[arch] = run_cv(arch, arch, wells.crops, wells, args, args.work_dir, keep_models=True)
        reports[arch] = cv_report(states[arch], wells, args)
    context_state = run_cv(
        "contexto_mobilenet_v2", "mobilenet_v2", wells.context, wells, args, args.work_dir, keep_models=False
    )
    context = cv_report(context_state, wells, args)

    # Sesión PXL fuera: los grupos con fotos PXL van completos a prueba
    pxl_mask = np.isin(wells.groups, np.unique(wells.groups[wells.sources == "PXL"]))
    train_idx, test_idx = np.flatnonzero(~pxl_mask), np.flatnonzero(pxl_mask)
    _, pxl_result = train_on(
        "mobilenet_v2", wells.crops, wells.labels, wells.groups, train_idx, test_idx, SEED, args
    )
    leave_pxl = full_report(
        wells.labels[test_idx],
        pxl_result["tuned"],
        wells.groups[test_idx],
        THRESHOLD,
        n_boot=args.n_boot,
        seed=SEED,
    )

    mean_probs = {arch: np.array(states[arch]["tuned"], dtype=float).mean(axis=0) for arch in names}
    comparison = None
    if len(names) >= 2:
        comparison = {
            "a": names[0],
            "b": names[1],
            **paired_auc_difference(
                wells.labels,
                mean_probs[names[0]],
                mean_probs[names[1]],
                wells.groups,
                n_boot=args.n_boot,
                seed=SEED,
            ),
        }
    figures = {"calibration": save_calibration_plot(reports)}
    explain = {arch: gradcam_examples(arch, wells, states[arch], args.work_dir) for arch in names}
    robust = {arch: robustness(arch, wells, states[arch], args.work_dir) for arch in names}
    best = max(names, key=lambda a: reports[a]["auc"])
    export = export_final(best, wells, args, args.work_dir)

    report = {
        "warning": "Evaluación, NO integrada en la app. Un solo dataset público, un tipo de celular y una "
        "paleta; etiquetas del autor del dataset, sin laboratorio. El aspecto anormal de la leche "
        "corresponde a mastitis clínica: la subclínica no cambia el aspecto y no se detecta así.",
        "source": SOURCE,
        "validation": f"StratifiedGroupKFold {args.splits}x{args.repeats}; grupos por pHash/dHash y "
        f"sesión PXL; umbral {THRESHOLD}; split original de Roboflow descartado por fuga",
        "input_size": args.size,
        "training": "Etapa 1: cabeza con la red congelada (lr 1e-3, parada temprana 10). Etapa 2: últimas 30 "
        "capas afinadas con aumento (giro, rotación ±15°, zoom, traslación, brillo, contraste), "
        "lr 1e-5, parada temprana 3. Pesos por clase balanceados.",
        "dataset": dataset,
        "cv": reports,
        "comparison_auc_difference": comparison,
        "context_only_control": context,
        "leave_pxl_session_out": {
            "train_wells": int(len(train_idx)),
            "test_wells": int(len(test_idx)),
            **leave_pxl,
        },
        "gradcam": explain,
        "robustness_rep0": robust,
        "figures": figures,
        "export": export,
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Informe en {REPORT_PATH}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
