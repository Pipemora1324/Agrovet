# ml — Modelo de alerta temprana

Generación del dataset, entrenamiento del modelo LSTM y exportación a TensorFlow Lite para la app.

> **Aviso sobre los datos.** Por ahora el modelo se entrena con un **dataset sintético**. Sus
> métricas sirven para comprobar que el pipeline funciona de punta a punta y **no validan la
> hipótesis del proyecto (F1 ≥ 0,80)**. El generador no se ajusta para mejorar las métricas.
> Cuando haya registros reales de fincas se reentrena con este mismo pipeline.

## Requisitos

Python 3.13.

```bash
cd ml
python -m venv .venv
.venv\Scripts\activate          # Windows  (Linux/Mac: source .venv/bin/activate)
pip install -r requirements.txt
```

## Pipeline

```bash
python src/generate_dataset.py      # data/daily_records.csv (no se versiona)
python src/train_lstm.py            # models/lstm.keras + reports/metrics.json y gráficas
python src/export_tflite.py         # models/mastitis_lstm.tflite + models/model_config.json
python src/export_test_vectors.py   # models/test_vectors.json
pytest                              # pruebas
flake8 src tests                    # estilo
```

| Archivo | Qué hace |
|---|---|
| `src/generate_dataset.py` | Dataset sintético por vaca y día. |
| `src/preprocess.py` | Limpieza, ventanas de 14 días y normalización. La app replica esta lógica en Dart. |
| `src/train_lstm.py` | Partición por vaca, entrenamiento, umbral y métricas. |
| `src/export_tflite.py` | Conversión a TFLite, comparación con Keras y `model_config.json`. |
| `src/export_test_vectors.py` | Casos de prueba para verificar la app contra Python. |

## Dataset sintético

- 600 vacas, 60 días, semilla fija (42). El 35 % (210 vacas) desarrolla mastitis clínica entre los días 20 y 56.
- Cada vaca tiene su propia línea base de temperatura, leche y alimento, con ruido diario y una leve
  caída de la producción a lo largo de la lactancia.
- **Fase subclínica** de 5 a 7 días antes del inicio clínico: la temperatura sube y la leche y el
  alimento bajan de forma progresiva, con intensidad proporcional a la severidad de cada caso.
- **Factores de confusión** que producen señales parecidas sin enfermedad:
  - celo cada ~21 días (el 30 % de las vacas no cicla, como si estuviera preñada);
  - rachas de estrés calórico compartidas por todo el hato.
- **Registros erróneos** (~2 %): decimal corrido, temperatura en Fahrenheit, un cero de más en la
  leche, alimento en cero o dato vacío.
- `days_to_onset` está vacío en vacas sanas y es negativo después del inicio clínico.

## Ventanas y normalización

- Ventanas de 14 días. Etiqueta positiva si el inicio clínico ocurre entre 1 y 5 días después del
  último día. Se descartan las ventanas que terminan en el inicio clínico o después.
- Un valor vacío o fuera de rango se trata como faltante y toma el último valor válido anterior.
  Si una variable tiene menos de 10 días válidos, la ventana no se evalúa.
  Rangos válidos: temperatura 35–42 °C, leche 0,5–45 L y alimento 0,5–35 kg.
- La base es la media de los primeros 7 días. Temperatura: `(t − base) / 0,5`.
  Leche y alimento: `(x / base − 1) / 0,1`.

## Modelo

LSTM(32) → Dropout(0,3) → Dense(16, relu) → Dense(1, sigmoide). Partición 70/15/15 por vaca,
estratificada. Pesos de clase balanceados y parada temprana sobre el AUC de validación. El umbral
es el que maximiza F1 en validación.

## Resultados actuales (dataset sintético)

> Estas cifras vienen de **datos sintéticos** y **no validan la hipótesis F1 ≥ 0,80**. Con estos
> datos el modelo **no** alcanza esa meta; se reportan tal como salieron.

Set de test: 90 vacas (32 enferman), 3514 ventanas, 160 positivas. Detalle en `reports/metrics.json`.

| Métrica (test) | Valor |
|---|---|
| F1 | 0,492 |
| Precisión | 0,525 |
| Sensibilidad | 0,463 |
| AUC ROC | 0,891 |
| AUC precisión-sensibilidad | 0,521 |
| Matriz de confusión | VN 3287 · FP 67 · FN 86 · VP 74 |
| Vacas enfermas con alerta 1–5 días antes | 30 de 32 (93,8 %) |
| Anticipación mediana de la primera alerta | 2 días |
| Vacas sanas con al menos una alerta roja | 31 de 58 (53,4 %) |
| Ventanas de vacas sanas en rojo | 2,0 % |

Umbral (máximo F1 en validación): **0,854**. Es alto porque los pesos de clase desplazan las
probabilidades hacia arriba; no debe leerse como una probabilidad calibrada.

Exportación a TFLite (`reports/export.json`): 62,7 KB, solo operaciones nativas de TFLite. Sobre las
3514 ventanas de test, la diferencia máxima entre Keras y TFLite es 3,6 × 10⁻⁷ y ambos toman la
misma decisión en el 100 % de los casos. Para exportar, el LSTM se desenrolla (14 pasos fijos):
es el mismo cálculo con los mismos pesos, sin bucles en el grafo.

## Semáforo

| Color | Probabilidad | Lectura |
|---|---|---|
| Verde | < 0,427 | Sin señales de riesgo |
| Amarillo | 0,427 a < 0,854 | Alerta temprana: vigilar y repetir el registro |
| Rojo | ≥ 0,854 | Alto riesgo: consultar al veterinario |

Decisión: se mantiene la regla del plan (amarillo desde la mitad del umbral). Se compararon en
validación otros cortes para el amarillo (sensibilidad del 90 %, 80 % y 70 %) y ninguno separa bien
a las vacas sanas. Con la regla elegida, en validación el 85,8 % de las ventanas de riesgo queda en
amarillo o rojo, a cambio de que el 21,5 % de las ventanas sanas quede en amarillo. Para un aviso
temprano se prefiere que el amarillo sea sensible y reservar el rojo para el umbral de F1. En test,
las ventanas sanas quedan 77,7 % verde, 20,3 % amarillo y 2,0 % rojo; las que terminan 1–5 días
antes del inicio, 21,3 % verde, 32,5 % amarillo y 46,3 % rojo.

## Artefactos que usa la app

Se versionan `models/mastitis_lstm.tflite`, `models/model_config.json` y `models/test_vectors.json`.
La app debe reproducir los 8 casos de `test_vectors.json` (normalización y probabilidad) con
tolerancia 1e-4.
