# ml — Modelo de alerta temprana

Generación del dataset, entrenamiento del modelo LSTM y exportación a TensorFlow Lite para la app.

Contenido previsto:

- `src/generate_dataset.py`: dataset sintético por vaca y día.
- `src/train_lstm.py`: entrenamiento y evaluación del LSTM (ventanas de 14 días).
- `src/export_tflite.py`: conversión a `.tflite` y `models/model_config.json`.
- `src/export_test_vectors.py`: casos de prueba para verificar la app contra Python.
- `reports/`: métricas y gráficas de la última evaluación.

Las instrucciones completas se agregan junto con el código.
