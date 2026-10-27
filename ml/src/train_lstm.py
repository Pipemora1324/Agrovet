"""Entrena y evalúa el LSTM de alerta temprana sobre el dataset sintético.

Salidas:
- models/lstm.keras (no se versiona)
- reports/metrics.json y gráficas PNG (curva ROC, PR, pérdida y matriz de confusión)

Las métricas provienen de datos sintéticos y NO validan la hipótesis F1 >= 0,80.
"""

import argparse
import json
from pathlib import Path

import matplotlib
import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.metrics import (auc, confusion_matrix, f1_score, precision_recall_curve,
                             precision_score, recall_score, roc_auc_score, roc_curve)
from sklearn.model_selection import train_test_split

from preprocess import BASE_DAYS, FEATURES, WINDOW_DAYS, build_windows, traffic_light

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

ML_DIR = Path(__file__).resolve().parents[1]
DATA_PATH = ML_DIR / "data" / "daily_records.csv"
MODEL_PATH = ML_DIR / "models" / "lstm.keras"
REPORTS_DIR = ML_DIR / "reports"
SEED = 42
SYNTHETIC_NOTE = ("Métricas obtenidas con un dataset sintético. Sirven para comprobar el pipeline; "
                  "NO validan la hipótesis del proyecto (F1 >= 0,80).")


def build_model(batch_size=None, unroll=False):
    """unroll=True solo para exportar: mismo cálculo, sin bucle WHILE en el grafo de TFLite."""
    inputs = tf.keras.Input(shape=(WINDOW_DAYS, len(FEATURES)), batch_size=batch_size, name="window")
    x = tf.keras.layers.LSTM(32, unroll=unroll, name="lstm")(inputs)
    x = tf.keras.layers.Dropout(0.3, name="dropout")(x)
    x = tf.keras.layers.Dense(16, activation="relu", name="dense")(x)
    outputs = tf.keras.layers.Dense(1, activation="sigmoid", name="probability")(x)
    return tf.keras.Model(inputs, outputs, name="mastitis_lstm")


def split_cows(df, seed=SEED):
    """Partición 70/15/15 por vaca, estratificada por si la vaca enferma."""
    cows = df.groupby("cow_id")["sick"].first()
    train, rest = train_test_split(cows.index, test_size=0.30, stratify=cows, random_state=seed)
    val, test = train_test_split(rest, test_size=0.50, stratify=cows.loc[rest], random_state=seed)
    return set(train), set(val), set(test)


def load_split_windows(data_path=DATA_PATH):
    df = pd.read_csv(data_path)
    X, y, meta = build_windows(df)
    train_ids, val_ids, test_ids = split_cows(df)
    parts = {}
    for name, ids in (("train", train_ids), ("val", val_ids), ("test", test_ids)):
        mask = meta["cow_id"].isin(ids).to_numpy()
        parts[name] = (X[mask], y[mask], meta[mask].reset_index(drop=True))
    return df, parts


def best_f1_threshold(y_true, prob):
    precision, recall, thresholds = precision_recall_curve(y_true, prob)
    f1 = 2 * precision * recall / np.clip(precision + recall, 1e-12, None)
    best = int(np.argmax(f1[:-1]))  # el último punto no tiene umbral asociado
    return float(thresholds[best])


def early_warning_stats(meta, prob, threshold):
    """Anticipación y falsas alarmas a nivel de vaca.

    - Detectada: la vaca enferma tiene al menos una alerta (prob >= umbral) en alguna ventana
      que termina entre 1 y 5 días antes del inicio clínico.
    - Anticipación: días entre la primera de esas alertas y el inicio clínico.
    - Falsas alarmas: alertas en ventanas de vacas que nunca enferman.
    """
    alerts = prob >= threshold
    sick = meta["sick"].to_numpy()
    in_horizon = sick & meta["days_to_onset"].between(1, 5).to_numpy()

    anticipation = []
    sick_cows = meta.loc[sick, "cow_id"].unique()
    for cow in sick_cows:
        cow_mask = (meta["cow_id"] == cow).to_numpy() & in_horizon & alerts
        if cow_mask.any():
            anticipation.append(float(meta.loc[cow_mask, "days_to_onset"].max()))

    healthy = ~sick
    healthy_cows = meta.loc[healthy, "cow_id"].unique()
    cows_with_alert = meta.loc[healthy & alerts, "cow_id"].nunique()
    colors = pd.Series([traffic_light(p, threshold) for p in prob])

    def color_share(mask):
        counts = colors[mask].value_counts(normalize=True)
        return {c: round(float(counts.get(c, 0.0)), 4) for c in ("green", "yellow", "red")}

    return {
        "early_warning": {
            "sick_cows": int(len(sick_cows)),
            "detected_cows": len(anticipation),
            "detection_rate": round(len(anticipation) / max(len(sick_cows), 1), 4),
            "median_anticipation_days": float(np.median(anticipation)) if anticipation else None,
            "definition": "Primera alerta (prob >= umbral) en ventanas que terminan 1 a 5 días antes "
                          "del inicio clínico; anticipación = días entre esa alerta y el inicio.",
        },
        "false_alarms": {
            "healthy_cows": int(len(healthy_cows)),
            "healthy_cows_with_alert": int(cows_with_alert),
            "healthy_cows_with_alert_rate": round(cows_with_alert / max(len(healthy_cows), 1), 4),
            "alert_windows": int((healthy & alerts).sum()),
            "healthy_windows": int(healthy.sum()),
            "alert_rate_per_window": round(float((healthy & alerts).sum() / max(healthy.sum(), 1)), 4),
            "definition": "Ventanas de vacas sanas con prob >= umbral (cada ventana = un día de evaluación).",
        },
        "traffic_light_share": {
            "healthy_windows": color_share(healthy),
            "windows_1_to_5_days_before_onset": color_share(in_horizon),
        },
    }


def save_plots(history, y_test, prob_test, cm):
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    caption = "Datos sintéticos: no valida la hipótesis"

    fig, ax = plt.subplots(figsize=(6, 4))
    ax.plot(history["loss"], label="entrenamiento")
    ax.plot(history["val_loss"], label="validación")
    ax.set_xlabel("época")
    ax.set_ylabel("pérdida (entropía cruzada)")
    ax.set_title(f"Pérdida — {caption}", fontsize=9)
    ax.legend()
    fig.tight_layout()
    fig.savefig(REPORTS_DIR / "loss.png", dpi=120)
    plt.close(fig)

    fpr, tpr, _ = roc_curve(y_test, prob_test)
    fig, ax = plt.subplots(figsize=(5, 5))
    ax.plot(fpr, tpr, label=f"AUC = {auc(fpr, tpr):.3f}")
    ax.plot([0, 1], [0, 1], "--", color="gray")
    ax.set_xlabel("tasa de falsos positivos")
    ax.set_ylabel("sensibilidad")
    ax.set_title(f"Curva ROC (test) — {caption}", fontsize=9)
    ax.legend()
    fig.tight_layout()
    fig.savefig(REPORTS_DIR / "roc.png", dpi=120)
    plt.close(fig)

    precision, recall, _ = precision_recall_curve(y_test, prob_test)
    fig, ax = plt.subplots(figsize=(5, 5))
    ax.plot(recall, precision, label=f"AUC-PR = {auc(recall, precision):.3f}")
    ax.set_xlabel("sensibilidad")
    ax.set_ylabel("precisión")
    ax.set_title(f"Curva precisión-sensibilidad (test) — {caption}", fontsize=9)
    ax.legend()
    fig.tight_layout()
    fig.savefig(REPORTS_DIR / "precision_recall.png", dpi=120)
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(4.5, 4))
    ax.imshow(cm, cmap="Blues")
    labels = ["sin riesgo", "riesgo 1-5 d"]
    ax.set_xticks([0, 1], labels)
    ax.set_yticks([0, 1], labels)
    ax.set_xlabel("predicción")
    ax.set_ylabel("real")
    for (i, j), value in np.ndenumerate(cm):
        ax.text(j, i, str(value), ha="center", va="center",
                color="white" if value > cm.max() / 2 else "black")
    ax.set_title(f"Matriz de confusión (test)\n{caption}", fontsize=9)
    fig.tight_layout()
    fig.savefig(REPORTS_DIR / "confusion_matrix.png", dpi=120)
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description="Entrena el LSTM de AgroVet.")
    parser.add_argument("--epochs", type=int, default=100)
    parser.add_argument("--batch-size", type=int, default=256)
    args = parser.parse_args()

    tf.keras.utils.set_random_seed(SEED)
    tf.config.experimental.enable_op_determinism()

    df, parts = load_split_windows()
    X_train, y_train, _ = parts["train"]
    X_val, y_val, meta_val = parts["val"]
    X_test, y_test, meta_test = parts["test"]

    positives = y_train.sum()
    class_weight = {0: len(y_train) / (2 * (len(y_train) - positives)),
                    1: len(y_train) / (2 * positives)}

    model = build_model()
    model.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
                  loss="binary_crossentropy",
                  metrics=[tf.keras.metrics.AUC(name="auc")])
    early_stopping = tf.keras.callbacks.EarlyStopping(monitor="val_auc", mode="max", patience=10,
                                                      restore_best_weights=True)
    fit = model.fit(X_train, y_train, validation_data=(X_val, y_val), epochs=args.epochs,
                    batch_size=args.batch_size, class_weight=class_weight,
                    callbacks=[early_stopping], verbose=2)
    history = fit.history

    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    model.save(MODEL_PATH)

    prob_val = model.predict(X_val, verbose=0).ravel()
    threshold = best_f1_threshold(y_val, prob_val)

    prob_test = model.predict(X_test, verbose=0).ravel()
    pred_test = (prob_test >= threshold).astype(int)
    cm = confusion_matrix(y_test, pred_test, labels=[0, 1])
    precision_curve, recall_curve, _ = precision_recall_curve(y_test, prob_test)

    best_epoch = int(np.argmax(history["val_auc"]))
    metrics = {
        "note": SYNTHETIC_NOTE,
        "dataset": {
            "records": int(len(df)),
            "cows": int(df["cow_id"].nunique()),
            "sick_cows": int(df.groupby("cow_id")["sick"].first().sum()),
            "erroneous_records": int(df["is_erroneous"].sum()),
        },
        "windows": {
            name: {"cows": int(meta["cow_id"].nunique()), "windows": int(len(y)), "positives": int(y.sum())}
            for name, (_, y, meta) in parts.items()
        },
        "preprocessing": {"window_days": WINDOW_DAYS, "base_days": BASE_DAYS, "features": list(FEATURES)},
        "threshold": round(threshold, 6),
        "threshold_selection": "Máximo F1 en validación",
        "test": {
            "f1": round(float(f1_score(y_test, pred_test)), 4),
            "precision": round(float(precision_score(y_test, pred_test)), 4),
            "recall": round(float(recall_score(y_test, pred_test)), 4),
            "roc_auc": round(float(roc_auc_score(y_test, prob_test)), 4),
            "pr_auc": round(float(auc(recall_curve, precision_curve)), 4),
            "confusion_matrix": {"tn": int(cm[0, 0]), "fp": int(cm[0, 1]),
                                 "fn": int(cm[1, 0]), "tp": int(cm[1, 1])},
        },
        **early_warning_stats(meta_test, prob_test, threshold),
        "validation": {
            "f1_at_threshold": round(float(f1_score(y_val, (prob_val >= threshold).astype(int))), 4),
            "roc_auc": round(float(roc_auc_score(y_val, prob_val)), 4),
        },
        "training": {
            "epochs_run": len(history["loss"]),
            "best_epoch": best_epoch + 1,
            "best_val_auc": round(float(history["val_auc"][best_epoch]), 4),
            "class_weight": {str(k): round(v, 4) for k, v in class_weight.items()},
            "seed": SEED,
        },
        "versions": {"tensorflow": tf.__version__, "keras": tf.keras.__version__},
    }

    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    with open(REPORTS_DIR / "metrics.json", "w", encoding="utf-8") as fh:
        json.dump(metrics, fh, ensure_ascii=False, indent=2)
    save_plots(history, y_test, prob_test, cm)

    print(json.dumps(metrics, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
