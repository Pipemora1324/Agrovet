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

## CNN de triaje visual de la ubre

`src/train_cnn.py` tiene el modelo y el entrenamiento que comparten las dos fuentes de fotos:
MobileNetV2 (alpha 0.35, ImageNet) congelada + cabeza binaria (sana / con signos de mastitis),
aumento de datos moderado (giro, rotación de ±15°, recorte aleatorio, brillo y contraste), pesos
de clase, parada temprana y ajuste fino de las últimas 30 capas. Se exporta a TFLite con pesos en
float16, solo con operaciones nativas.

> **En la app está APAGADA por defecto** (`--dart-define=UDDER_TRIAGE=true` la enciende) y así
> debe quedar: ver la recomendación al final de esta sección. Si se enciende, la app dice
> "Resultado orientativo, no es diagnóstico".

### Con el dataset público (Roboflow, CC BY 4.0)

Fuente, licencia y cambios en [docs/datasets_publicos.md](../docs/datasets_publicos.md). Los datos
no están en el repo:

```bash
python src/train_udder_public.py --coco "<ruta>/Mastitis.v1-v1.coco" --work-dir "<ruta fuera del repo>"
```

- Recorte: caja del polígono + 10 % de margen, relleno negro a cuadrado, 224 px. Se descartan 7
  fotos con lado corto < 96 px: quedan **117 (56 sanas, 61 con mastitis)**.
- Grupos por vaca o escena: hash perceptual (pHash de la foto y del recorte, también reflejado),
  números consecutivos con colores parecidos y **22 uniones de una revisión manual** de las 124 fotos
  (`MANUAL_SAME_ANIMAL` en `src/udder_public_data.py`; 11.jpg es la misma ubre que 9 y 10). Los 20
  grupos automáticos del informe se quedaban cortos. Resultado: 71 grupos independientes en las 117
  fotos. Dos grupos tienen etiquetas distintas en la misma ubre (img-51/53, img-105/107).
- Validación: `StratifiedGroupKFold` 5 × 5 por grupo; dentro de cada fold, un sexto de los grupos
  de entrenamiento para la parada temprana. Cada foto se predice 5 veces sin haberla visto; se
  reporta la probabilidad media con umbral 0,5. Sensibilidad y especificidad con IC 95 % de Wilson
  (por foto: algo optimista porque las fotos de un grupo no son independientes), AUC con IC 95 % por
  bootstrap de grupos (2000 remuestreos). Detalle en `reports/udder_cnn_public.json`.

> Las etiquetas son del autor del dataset, **sin confirmación veterinaria**. Estas cifras miden
> concordancia con esas etiquetas, no capacidad diagnóstica.

| Experimento (5 × 5, umbral 0,5) | Fotos | Sensibilidad (IC 95 %) | Especificidad (IC 95 %) | AUC (IC 95 %) |
|---|---|---|---|---|
| Recorte de la ubre, todas las fotos | 117 | 0,77 (0,65–0,86) | 0,89 (0,79–0,95) | 0,87 (0,76–0,96) |
| El mismo modelo, evaluado solo en la serie img-N (establo) | 85 | 0,58 (0,41–0,74) | 0,89 (0,78–0,95) | 0,76 (0,58–0,92) |
| Entrenado y evaluado solo en img-N | 85 | 0,55 (0,38–0,71) | 0,91 (0,80–0,96) | 0,81 (0,65–0,94) |
| **Solo el fondo** (ubre tapada en negro) | 117 | 0,74 (0,62–0,83) | 0,70 (0,57–0,80) | **0,75 (0,62–0,87)** |

Matriz de confusión del modelo principal (todas las fotos): VN 50 · FP 6 · FN 14 · VP 47. Entre
las 5 repeticiones el AUC varía 0,854 ± 0,014. La serie N (fotos de potrero o de banco de imágenes,
todas con mastitis) se detecta en 29 de 30 casos.

**Sesgo de fondo: confirmado.** Un modelo que no ve la ubre, solo el entorno, acierta muy por
encima del azar (AUC 0,75). En el dataset, el potrero, el cielo y las marcas de agua de los bancos
de imágenes vienen solo con fotos de mastitis, y las sanas casi solo del establo. Cuando se quita
ese atajo (serie img-N, mismo establo), **la sensibilidad cae a 0,55–0,58: se escapa casi la mitad
de las mastitis**. El 0,77 global está inflado por las fotos de potrero.

Exportación (`reports/udder_cnn_public.json`, sección `export`): 870 KB en float16. Frente a Keras,
sobre las 117 fotos: diferencia máxima 0,024, media 0,006, misma decisión en 115 de 117 (las 2 que
cambian están en el umbral: 0,496 frente a 0,509). Se probaron también float32 (1,6 MB, diferencia
5 × 10⁻⁶; no cabe en el APK) e int8 (0,55 MB, diferencia hasta 0,09 y 3 decisiones distintas). La
tolerancia de paridad se fijó en 0,01 y **se subió a 0,03 después de ver** el resultado de float16.
La app reproduce el TFLite de Python sobre 4 patrones sintéticos (`models/udder_cnn_vectors.json`).

**Recomendación: no encender el triaje visual.** El modelo aprende parte del entorno y no de la
ubre; en el único escenario parecido al uso real (establo) pierde casi la mitad de las mastitis, las
etiquetas no tienen confirmación veterinaria y no hay fotos de Nariño. Queda como prueba de que el
pipeline funciona de punta a punta. Antes de encenderlo hacen falta fotos propias confirmadas por un
veterinario (la app ya las recoge con permiso) y repetir esta misma evaluación con ellas.

### Con fotos de los ganaderos

`python src/train_cnn.py` entrena con las fotos confirmadas por un veterinario. Sin al menos 50 por
clase en `data/udder_images/healthy/` y `data/udder_images/mastitis/` (carpetas que no se versionan),
termina sin entrenar. Cada foto tiene, en la app, "¿Un veterinario confirmó el diagnóstico?" (Sí / No / Pendiente), el
diagnóstico (Mastitis / Sana / Otro) y el interruptor "Permitir usar esta foto para investigación",
**apagado por defecto**. `src/build_cnn_dataset.py` arma `data/udder_images/` solo con las fotos que
tienen el permiso activado, confirmación del veterinario y diagnóstico Mastitis o Sana:

```bash
# Desde backend/: manifiesto (no se versiona) y copia de las fotos del volumen
docker compose exec -T db psql -U agrovet -d agrovet -c "\copy (SELECT id, vet_confirmed, diagnosis, research_consent, deleted, stored FROM cow_photos) TO STDOUT CSV HEADER" > ../ml/data/fotos.csv
docker compose cp backend:/app/data/photos ../ml/data/fotos_servidor
# Desde ml/:
python src/build_cnn_dataset.py --manifest data/fotos.csv --photos data/fotos_servidor
python src/train_cnn.py
```

Los archivos copiados se nombran solo con el id de la foto, sin datos del ganadero.

### Prueba de humo (sin valor científico)

`tests/test_train_cnn.py::test_smoke_training_runs_end_to_end_without_scientific_value` genera 10
imágenes de ruido y corre el pipeline completo (entrenamiento, ajuste fino y exportación a TFLite)
sin descargar pesos. **Solo comprueba que el código funciona**: sus números no significan nada y no
se guardan en `reports/`.

## Prueba de concepto: pocillos de leche (no se usa en la app)

`src/milk_public_poc.py` clasifica cada pocillo de la paleta como leche normal o anormal con la
misma CNN, usando el dataset público de leche de Roboflow (CC BY 4.0, ver
[docs/datasets_publicos.md](../docs/datasets_publicos.md)). Se ignoran los splits de Roboflow (40
grupos de frames casi idénticos estaban repartidos entre train, valid y test) y se agrupa por pHash:
640 pocillos (189 normales, 451 anormales) en 200 grupos. Validación `StratifiedGroupKFold` 5 × 1 (una
sola repetición, por tiempo) y una prueba extra: entrenar sin la sesión de fotos de teléfono (PXL) y
evaluar solo en ella. Detalle en `reports/milk_poc_public.json`.

| Evaluación (umbral 0,5) | Pocillos | Sensibilidad (IC 95 %) | Especificidad (IC 95 %) | AUC (IC 95 %) |
|---|---|---|---|---|
| Validación cruzada por grupos | 640 | 0,96 (0,94–0,97) | 1,00 (0,98–1,00) | 0,999 (0,996–1,000) |
| Sin la sesión PXL, evaluada solo en ella | 113 | 1,00 (0,86–1,00) | 1,00 (0,96–1,00) | 1,00 |

No cae al sacar la sesión PXL, así que no parece haber aprendido la sesión. Los 18 pocillos anormales
que no detecta son casi todos "Curd like" (17 de 116). **Advertencia**: la tarea es fácil en estas
condiciones (sangre roja, grumos o líquido oscuro frente a leche blanca, misma paleta, mismo suelo y
misma luz). No hay casos sutiles, las etiquetas son del autor sin laboratorio y la prueba PXL es
pequeña (24 anormales). No dice nada de cómo funcionaría con otra paleta, otra luz u otra cámara, ni
sobre la mastitis subclínica, que no cambia el aspecto de la leche.

## Artefactos que usa la app

Se versionan `models/mastitis_lstm.tflite`, `models/model_config.json` y `models/test_vectors.json`.
La app debe reproducir los 8 casos de `test_vectors.json` (normalización y probabilidad) con
tolerancia 1e-4.

También `models/udder_cnn.tflite`, `models/udder_cnn_config.json` y `models/udder_cnn_vectors.json`
(CNN de la ubre, apagada en la app). La app debe dar lo mismo que el TFLite de Python (1e-4) sobre
los 4 patrones sintéticos. El `.keras` y las predicciones por foto quedan fuera del repo.
