"""Estructura del triaje visual de la ubre con una CNN (MobileNetV2 + transfer learning).

DESACTIVADA: todavía no hay fotos reales etiquetadas. Este script deja listo el pipeline para
cuando existan; sin imágenes termina sin entrenar nada. No se usan imágenes sintéticas ni de
internet para "rellenar", porque los resultados no tendrían valor.

Cuando haya fotos, se ponen en:
    ml/data/udder_images/healthy/   (ubre sana)
    ml/data/udder_images/mastitis/  (ubre con signos de mastitis)
y se ejecuta: python src/train_cnn.py
"""

import argparse
import json
from pathlib import Path

import tensorflow as tf

ML_DIR = Path(__file__).resolve().parents[1]
IMAGES_DIR = ML_DIR / "data" / "udder_images"
MODEL_PATH = ML_DIR / "models" / "udder_cnn.keras"
TFLITE_PATH = ML_DIR / "models" / "udder_cnn.tflite"
REPORT_PATH = ML_DIR / "reports" / "cnn_metrics.json"
IMAGE_SIZE = (224, 224)
CLASSES = ("healthy", "mastitis")
IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png"}
MIN_IMAGES_PER_CLASS = 50
SEED = 42


def count_images(images_dir=IMAGES_DIR):
    counts = {}
    for name in CLASSES:
        folder = images_dir / name
        files = folder.glob("*") if folder.exists() else []
        counts[name] = sum(1 for f in files if f.suffix.lower() in IMAGE_SUFFIXES)
    return counts


def build_cnn(weights="imagenet"):
    """MobileNetV2 congelada + cabeza binaria. weights=None solo para pruebas sin descargar pesos."""
    inputs = tf.keras.Input(shape=(*IMAGE_SIZE, 3), name="image")
    x = tf.keras.layers.Rescaling(1 / 127.5, offset=-1, name="to_minus1_1")(inputs)
    backbone = tf.keras.applications.MobileNetV2(input_shape=(*IMAGE_SIZE, 3), include_top=False,
                                                 weights=weights)
    backbone.trainable = False
    x = backbone(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.2)(x)
    outputs = tf.keras.layers.Dense(1, activation="sigmoid", name="mastitis_probability")(x)
    return tf.keras.Model(inputs, outputs, name="udder_cnn"), backbone


def train(images_dir, epochs, fine_tune_epochs):
    train_ds, val_ds = tf.keras.utils.image_dataset_from_directory(
        images_dir, labels="inferred", label_mode="binary", class_names=list(CLASSES),
        image_size=IMAGE_SIZE, batch_size=16, validation_split=0.2, subset="both", seed=SEED)
    augment = tf.keras.Sequential([
        tf.keras.layers.RandomFlip("horizontal"),
        tf.keras.layers.RandomRotation(0.05),
        tf.keras.layers.RandomBrightness(0.15),
    ])
    train_ds = train_ds.map(lambda x, y: (augment(x, training=True), y)).prefetch(tf.data.AUTOTUNE)
    val_ds = val_ds.prefetch(tf.data.AUTOTUNE)

    model, backbone = build_cnn()
    metrics = [tf.keras.metrics.AUC(name="auc"), tf.keras.metrics.Recall(name="recall")]
    model.compile(optimizer=tf.keras.optimizers.Adam(1e-3), loss="binary_crossentropy", metrics=metrics)
    model.fit(train_ds, validation_data=val_ds, epochs=epochs)

    # Ajuste fino de las últimas capas con una tasa de aprendizaje baja
    backbone.trainable = True
    for layer in backbone.layers[:-30]:
        layer.trainable = False
    model.compile(optimizer=tf.keras.optimizers.Adam(1e-5), loss="binary_crossentropy", metrics=metrics)
    history = model.fit(train_ds, validation_data=val_ds, epochs=fine_tune_epochs)

    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    model.save(MODEL_PATH)
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
    TFLITE_PATH.write_bytes(converter.convert())
    return {name: float(values[-1]) for name, values in history.history.items()}


def main():
    parser = argparse.ArgumentParser(
        description="Entrena la CNN de triaje visual de la ubre (desactivada).")
    parser.add_argument("--images", type=Path, default=IMAGES_DIR)
    parser.add_argument("--epochs", type=int, default=10)
    parser.add_argument("--fine-tune-epochs", type=int, default=5)
    args = parser.parse_args()

    counts = count_images(args.images)
    missing = {name: n for name, n in counts.items() if n < MIN_IMAGES_PER_CLASS}
    if missing:
        print(f"Imágenes encontradas: {counts}. Se necesitan al menos {MIN_IMAGES_PER_CLASS} reales "
              f"por clase en {args.images}. La CNN sigue desactivada; no se entrenó nada.")
        return 0

    metrics = train(args.images, args.epochs, args.fine_tune_epochs)
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps({"images": counts, "validation": metrics}, indent=2), encoding="utf-8")
    print(json.dumps(metrics, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
