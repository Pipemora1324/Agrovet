"""Prueba de concepto: clasificar cada pocillo de la paleta como leche normal o anormal.

NO se integra en la app. Dataset: "Mastitis dataset" v3 de Roboflow Universe (CC BY 4.0), 453
imágenes (frames de video y fotos de teléfono) con una caja por pocillo: Normal, Watery, Curd like y
Blood tinged Milk. Ver docs/datasets_publicos.md.

Uso (datos FUERA del repositorio):
    python src/milk_public_poc.py --coco "C:/.../Data/roboflow_leche/Mastitis dataset.v3i.coco"
                                  --work-dir "C:/.../Data/agrovet_work/milk"

Cambios sobre el dataset: se ignoran los splits de Roboflow (tienen fuga: frames casi idénticos en
train, valid y test); cada caja se recorta (+10 % de margen, cuadrado, 224 px) y se etiqueta
normal (0) / anormal (1); las imágenes se agrupan por hash perceptual y cada grupo va completo a un
fold. Prueba extra: entrenar sin la sesión de fotos de teléfono (PXL_*) y evaluar solo en ella.
"""

import argparse
import json
import time
from pathlib import Path

import numpy as np
import tensorflow as tf
from PIL import Image

from cnn_evaluation import (balanced_class_weight, inner_validation_split, repeated_group_folds,
                            summarize)
from train_cnn import ALPHA, array_dataset, build_cnn, fit_two_phase, make_augmenter
from udder_public_data import _UnionFind, hamming, phash, udder_crop

ML_DIR = Path(__file__).resolve().parents[1]
REPORT_PATH = ML_DIR / "reports" / "milk_poc_public.json"
SPLITS = ("train", "valid", "test")
NORMAL = "Normal Milk"
PHASH_SAME, DHASH_SAME = 8, 12
MIN_BOX_SIDE = 64
SEED = 42
THRESHOLD = 0.5


def dhash(image):
    gray = np.asarray(image.convert("L").resize((9, 8), Image.LANCZOS), dtype=float)
    return (gray[:, 1:] > gray[:, :-1]).ravel()


def source_of(name):
    """Sesión aparente según el nombre original: fotos de teléfono (PXL) o frames de video."""
    return "PXL" if name.startswith("PXL_") else "video"


def load_boxes(coco_dir):
    """Una entrada por imagen (con sus cajas) de los tres splits de Roboflow, que aquí se ignoran."""
    coco_dir = Path(coco_dir)
    images = []
    for split in SPLITS:
        data = json.loads((coco_dir / split / "_annotations.coco.json").read_text(encoding="utf-8"))
        cats = {c["id"]: c["name"] for c in data["categories"]}
        boxes = {}
        for ann in data["annotations"]:
            boxes.setdefault(ann["image_id"], []).append((cats[ann["category_id"]], ann["bbox"]))
        for im in data["images"]:
            name = im.get("extra", {}).get("name", im["file_name"])
            images.append({"name": name, "path": coco_dir / split / im["file_name"], "split": split,
                           "source": source_of(name), "boxes": boxes.get(im["id"], [])})
    return images


def group_images(images, pils):
    """Une imágenes casi idénticas (pHash <= 8 y dHash <= 12): frames contiguos del mismo video."""
    ph = [phash(p) for p in pils]
    dh = [dhash(p) for p in pils]
    uf = _UnionFind(len(images))
    for i in range(len(images)):
        for k in range(i + 1, len(images)):
            if hamming(ph[i], ph[k]) <= PHASH_SAME and hamming(dh[i], dh[k]) <= DHASH_SAME:
                uf.union(i, k)
    roots = {}
    return [roots.setdefault(uf.find(i), len(roots)) for i in range(len(images))]


def build_crops(images, pils, image_groups):
    crops, labels, groups, sources, grades = [], [], [], [], []
    for im, pil, group in zip(images, pils, image_groups):
        for grade, (x, y, w, h) in im["boxes"]:
            if min(w, h) * 1.2 < MIN_BOX_SIDE:
                continue
            crops.append(udder_crop(pil, (x, y, w, h)))   # mismo recorte: caja + 10 %, cuadrado, 224
            labels.append(0 if grade == NORMAL else 1)
            groups.append(group)
            sources.append(im["source"])
            grades.append(grade)
    return (np.stack(crops), np.array(labels), np.array(groups), np.array(sources), np.array(grades))


def fit_and_predict(images, labels, groups, train_idx, test_idx, args, seed):
    tf.keras.backend.clear_session()
    tf.keras.utils.set_random_seed(seed)
    fit_idx, val_idx = inner_validation_split(labels, groups, train_idx, seed=seed)
    train_ds = array_dataset(images[fit_idx], labels[fit_idx], args.batch, make_augmenter(seed),
                             shuffle=True, seed=seed)
    val_ds = array_dataset(images[val_idx], labels[val_idx], args.batch)
    model, backbone = build_cnn()
    fit_two_phase(model, backbone, train_ds, val_ds, args.epochs, args.fine_tune_epochs,
                  class_weight=balanced_class_weight(labels[fit_idx]), patience=args.patience)
    return model.predict(images[test_idx].astype(np.float32), verbose=0).ravel()


def main():
    parser = argparse.ArgumentParser(description="Prueba de concepto: pocillo normal o anormal.")
    parser.add_argument("--coco", type=Path, required=True)
    parser.add_argument("--work-dir", type=Path, required=True)
    parser.add_argument("--splits", type=int, default=5)
    parser.add_argument("--repeats", type=int, default=3)
    parser.add_argument("--epochs", type=int, default=30)
    parser.add_argument("--fine-tune-epochs", type=int, default=20)
    parser.add_argument("--patience", type=int, default=5)
    parser.add_argument("--batch", type=int, default=32)
    args = parser.parse_args()
    repo = ML_DIR.parent.resolve()
    if any(repo == p or repo in p.parents for p in (args.work_dir.resolve(), args.coco.resolve())):
        raise SystemExit("Los datos y las salidas por imagen deben quedar fuera del repositorio.")
    args.work_dir.mkdir(parents=True, exist_ok=True)

    images = load_boxes(args.coco)
    pils = [Image.open(im["path"]).convert("RGB") for im in images]
    image_groups = group_images(images, pils)
    crops, labels, groups, sources, grades = build_crops(images, pils, image_groups)
    leak = sum(1 for g in set(image_groups)
               if len({im["split"] for im, gg in zip(images, image_groups) if gg == g}) > 1)
    dataset = {
        "images": len(images), "image_groups": len(set(image_groups)),
        "groups_spanning_roboflow_splits": leak,
        "wells": int(len(labels)), "normal": int((labels == 0).sum()), "abnormal": int((labels == 1).sum()),
        "wells_by_grade": {g: int((grades == g).sum()) for g in sorted(set(grades))},
        "wells_by_source": {s: {"normal": int(((sources == s) & (labels == 0)).sum()),
                                "abnormal": int(((sources == s) & (labels == 1)).sum())}
                            for s in sorted(set(sources))},
    }
    print("[datos]", json.dumps(dataset), flush=True)

    probs = np.full((args.repeats, len(labels)), np.nan)
    folds = repeated_group_folds(labels, groups, args.splits, args.repeats, SEED)
    for rep, fold, train_idx, test_idx in folds:
        start = time.time()
        probs[rep, test_idx] = fit_and_predict(crops, labels, groups, train_idx, test_idx, args,
                                               SEED + 100 * rep + fold)
        print(f"[cv] rep {rep} fold {fold} {time.time() - start:.0f}s", flush=True)
    pooled = summarize(labels, probs.mean(axis=0), groups, THRESHOLD, seed=SEED)
    per_rep = [summarize(labels, p, groups, THRESHOLD, n_boot=200, seed=SEED)["auc"] for p in probs]

    # Sin la sesión PXL: los grupos que tocan alguna foto PXL van completos a prueba
    pxl_groups = set(groups[sources == "PXL"])
    test_mask = np.isin(groups, list(pxl_groups))
    train_idx, test_idx = np.flatnonzero(~test_mask), np.flatnonzero(test_mask)
    pxl_probs = fit_and_predict(crops, labels, groups, train_idx, test_idx, args, SEED)
    pxl = summarize(labels[test_idx], pxl_probs, groups[test_idx], THRESHOLD, seed=SEED)
    # La misma sesión PXL evaluada dentro de la validación cruzada (con fotos PXL en entrenamiento)
    in_cv_pxl = summarize(labels[test_mask], probs.mean(axis=0)[test_mask], groups[test_mask], THRESHOLD,
                          seed=SEED)
    print("[pxl]", json.dumps(pxl), flush=True)

    report = {
        "warning": "Prueba de concepto, NO integrada en la app. Etiquetas del autor del dataset, sin "
                   "laboratorio ni veterinario; un solo entorno (misma paleta, suelo y mano).",
        "source": {"name": "Mastitis dataset v3 (Roboflow Universe)",
                   "url": "https://universe.roboflow.com/abdurrehman4198-gmail-com/mastitis-dataset",
                   "license": "CC BY 4.0"},
        "model": f"MobileNetV2 alpha {ALPHA}, mismo entrenamiento que la CNN de la ubre",
        "validation": f"StratifiedGroupKFold {args.splits}x{args.repeats} por grupo de pHash; umbral 0.5",
        "dataset": dataset,
        "cv_pooled_mean_probability": pooled,
        "cv_auc_across_repeats": {"mean": float(np.mean(per_rep)), "min": float(np.min(per_rep)),
                                  "max": float(np.max(per_rep))},
        "leave_pxl_session_out": pxl,
        "pxl_session_inside_cv": in_cv_pxl,
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    (args.work_dir / "oof.json").write_text(json.dumps({
        "labels": labels.tolist(), "groups": groups.tolist(), "sources": sources.tolist(),
        "grades": grades.tolist(), "cv": probs.tolist(), "pxl_test_idx": test_idx.tolist(),
        "pxl_probs": pxl_probs.tolist()}), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
