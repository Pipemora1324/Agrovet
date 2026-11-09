"""CNN de triaje visual de la ubre (MobileNetV2 + transfer learning).

Hay dos fuentes de fotos y las dos usan las funciones de este archivo (modelo, aumento de datos,
entrenamiento en dos fases y exportación a TFLite):

1. Fotos de los ganaderos con diagnóstico confirmado por un veterinario (build_cnn_dataset.py).
   Todavía no hay suficientes: sin MIN_IMAGES_PER_CLASS por clase este script termina sin entrenar.
       ml/data/udder_images/healthy/   (ubre sana)
       ml/data/udder_images/mastitis/  (ubre con signos de mastitis)
       python src/train_cnn.py
2. El dataset público de Roboflow (CC BY 4.0), con validación cruzada agrupada por vaca:
   train_udder_public.py. Sus etiquetas son del autor del dataset, no de un veterinario.

En la app el modelo queda APAGADO por defecto; si se enciende, el resultado es orientativo y no es
un diagnóstico.
"""

import argparse
import json
from pathlib import Path

import numpy as np
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
FINE_TUNE_LAYERS = 30
# Ancho de MobileNetV2. 0.35 es la variante estrecha con pesos ImageNet: con la cuantización int8
# ocupa ~0,6 MB. El APK x86_64 de la app ya pesa ~14 MB y el límite es 15 MB; la variante completa
# (1.0) cuantizada ocupa ~2,6 MB y no cabe.
ALPHA = 0.35
SEED = 42


def count_images(images_dir=IMAGES_DIR):
    counts = {}
    for name in CLASSES:
        folder = images_dir / name
        files = folder.glob("*") if folder.exists() else []
        counts[name] = sum(1 for f in files if f.suffix.lower() in IMAGE_SUFFIXES)
    return counts


def build_cnn(weights="imagenet", dropout=0.3, alpha=ALPHA):
    """MobileNetV2 congelada + cabeza binaria. Entrada: RGB 0-255 en float32 (el reescalado a [-1, 1]
    va dentro del modelo). weights=None solo para pruebas sin descargar pesos."""
    inputs = tf.keras.Input(shape=(*IMAGE_SIZE, 3), name="image")
    x = tf.keras.layers.Rescaling(1 / 127.5, offset=-1, name="to_minus1_1")(inputs)
    backbone = tf.keras.applications.MobileNetV2(input_shape=(*IMAGE_SIZE, 3), include_top=False,
                                                 weights=weights, alpha=alpha)
    backbone.trainable = False
    # training=False deja la normalización por lotes en modo inferencia también al ajustar
    x = backbone(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(dropout)(x)
    outputs = tf.keras.layers.Dense(1, activation="sigmoid", name="mastitis_probability")(x)
    return tf.keras.Model(inputs, outputs, name="udder_cnn"), backbone


def make_augmenter(seed=None):
    """Aumento moderado, solo en entrenamiento (no queda en el modelo exportado): giro horizontal,
    rotación de hasta ±15°, recorte aleatorio (zoom hacia dentro y desplazamiento), brillo y
    contraste. No se toca el tono: el color de la piel es parte de la señal."""
    return tf.keras.Sequential([
        tf.keras.layers.RandomFlip("horizontal", seed=seed),
        tf.keras.layers.RandomRotation(15 / 360, fill_mode="constant", seed=seed),
        tf.keras.layers.RandomZoom((-0.15, 0.0), fill_mode="constant", seed=seed),
        tf.keras.layers.RandomTranslation(0.05, 0.05, fill_mode="constant", seed=seed),
        tf.keras.layers.RandomBrightness(0.2, value_range=(0, 255), seed=seed),
        tf.keras.layers.RandomContrast(0.2, seed=seed),
    ], name="augment")


def array_dataset(images, labels, batch_size, augment=None, shuffle=False, seed=SEED):
    """tf.data a partir de arreglos uint8 (N, 224, 224, 3) y etiquetas 0/1."""
    ds = tf.data.Dataset.from_tensor_slices((images.astype(np.float32), labels.astype(np.float32)))
    if shuffle:
        ds = ds.shuffle(len(images), seed=seed, reshuffle_each_iteration=True)
    ds = ds.batch(batch_size)
    if augment is not None:
        ds = ds.map(lambda x, y: (tf.clip_by_value(augment(x, training=True), 0.0, 255.0), y),
                    num_parallel_calls=tf.data.AUTOTUNE)
    return ds.prefetch(tf.data.AUTOTUNE)


def _metrics():
    return [tf.keras.metrics.AUC(name="auc"), tf.keras.metrics.Recall(name="recall")]


def fit_two_phase(model, backbone, train_ds, val_ds, epochs, fine_tune_epochs, class_weight=None,
                  patience=5, fine_tune_layers=FINE_TUNE_LAYERS, verbose=0):
    """Fase 1: solo la cabeza (backbone congelada, lr 1e-3). Fase 2: ajuste fino de las últimas
    capas de la backbone (lr 1e-5). Parada temprana sobre la pérdida de validación en ambas, con
    los mejores pesos restaurados. Devuelve el historial de cada fase."""
    def stopper():
        return [tf.keras.callbacks.EarlyStopping(monitor="val_loss", patience=patience,
                                                 restore_best_weights=True)]

    model.compile(optimizer=tf.keras.optimizers.Adam(1e-3), loss="binary_crossentropy", metrics=_metrics())
    head = model.fit(train_ds, validation_data=val_ds, epochs=epochs, class_weight=class_weight,
                     callbacks=stopper(), verbose=verbose)

    backbone.trainable = True
    for layer in backbone.layers[:-fine_tune_layers]:
        layer.trainable = False
    model.compile(optimizer=tf.keras.optimizers.Adam(1e-5), loss="binary_crossentropy", metrics=_metrics())
    tune = model.fit(train_ds, validation_data=val_ds, epochs=fine_tune_epochs, class_weight=class_weight,
                     callbacks=stopper(), verbose=verbose)
    return {"head": head.history, "fine_tune": tune.history}


def export_tflite(model, tflite_path, quantize=None):
    """Convierte a TFLite solo con operaciones nativas.
    quantize=None: float32. "float16": pesos en float16 (la mitad, diferencia ~1e-3).
    "int8" (o True): pesos en int8 por rango dinámico (un cuarto, diferencia de hasta ~0,1)."""
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
    if quantize:
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
    if quantize == "float16":
        converter.target_spec.supported_types = [tf.float16]
    tflite_path = Path(tflite_path)
    tflite_path.parent.mkdir(parents=True, exist_ok=True)
    tflite_path.write_bytes(converter.convert())
    return tflite_path.stat().st_size


def tflite_predict(tflite_path, images):
    """Probabilidades del modelo TFLite para un arreglo (N, 224, 224, 3), una imagen a la vez
    (como en la app)."""
    interpreter = tf.lite.Interpreter(model_path=str(tflite_path))
    interpreter.allocate_tensors()
    inp = interpreter.get_input_details()[0]["index"]
    out = interpreter.get_output_details()[0]["index"]
    probabilities = []
    for image in np.asarray(images, dtype=np.float32):
        interpreter.set_tensor(inp, image[None])
        interpreter.invoke()
        probabilities.append(float(interpreter.get_tensor(out)[0][0]))
    return np.array(probabilities)


def train(images_dir, epochs, fine_tune_epochs, model_path=MODEL_PATH, tflite_path=TFLITE_PATH,
          weights="imagenet", batch_size=16):
    """Fotos de los ganaderos (carpetas healthy/ y mastitis/): entrena, ajusta y exporta.
    weights=None y rutas temporales solo en la prueba de humo."""
    train_ds, val_ds = tf.keras.utils.image_dataset_from_directory(
        images_dir, labels="inferred", label_mode="binary", class_names=list(CLASSES),
        image_size=IMAGE_SIZE, batch_size=batch_size, validation_split=0.2, subset="both", seed=SEED)
    augment = make_augmenter(SEED)
    train_ds = train_ds.map(lambda x, y: (tf.clip_by_value(augment(x, training=True), 0.0, 255.0), y))
    train_ds, val_ds = train_ds.prefetch(tf.data.AUTOTUNE), val_ds.prefetch(tf.data.AUTOTUNE)

    model, backbone = build_cnn(weights=weights)
    history = fit_two_phase(model, backbone, train_ds, val_ds, epochs, fine_tune_epochs)

    model_path.parent.mkdir(parents=True, exist_ok=True)
    model.save(model_path)
    export_tflite(model, tflite_path, quantize="float16")
    return {name: float(values[-1]) for name, values in history["fine_tune"].items()}


def main():
    parser = argparse.ArgumentParser(
        description="Entrena la CNN de la ubre con fotos confirmadas por un veterinario.")
    parser.add_argument("--images", type=Path, default=IMAGES_DIR)
    parser.add_argument("--epochs", type=int, default=30)
    parser.add_argument("--fine-tune-epochs", type=int, default=20)
    args = parser.parse_args()

    counts = count_images(args.images)
    missing = {name: n for name, n in counts.items() if n < MIN_IMAGES_PER_CLASS}
    if missing:
        print(f"Imágenes encontradas: {counts}. Se necesitan al menos {MIN_IMAGES_PER_CLASS} reales "
              f"por clase en {args.images}. La CNN con fotos de los ganaderos sigue desactivada; "
              "no se entrenó nada. Para el dataset público use src/train_udder_public.py.")
        return 0

    metrics = train(args.images, args.epochs, args.fine_tune_epochs)
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps({"images": counts, "validation": metrics}, indent=2), encoding="utf-8")
    print(json.dumps(metrics, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
