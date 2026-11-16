# Calidad de los datos y límites de los modelos

Resumen de la evidencia de calidad de los datos y de los modelos. Las fuentes completas están en
[docs/datasets_publicos.md](../../datasets_publicos.md) y [ml/README.md](../../../ml/README.md).
Issue: #84.

## 1. LSTM de alerta temprana: dataset sintético

| Elemento | Valor |
|---|---|
| Datos | `ml/src/generate_dataset.py`: 600 vacas, 60 días, 35 % enferman, semilla 42, línea base por vaca, celo, estrés calórico, ~2 % de registros erróneos y fase subclínica de 5 a 7 días |
| Partición | 70/15/15 **por vaca** y estratificada (`test_split_has_no_cow_leakage_and_is_stratified`) |
| Umbral | 0,854394, elegido por F1 en validación |
| Test | F1 **0,492**, precisión 0,525, sensibilidad 0,463, AUC 0,891 |
| Exportación | TFLite solo con TFLITE_BUILTINS; diferencia máxima Keras vs. TFLite 3,58e-7; la app reproduce los 8 vectores con tolerancia 1e-4 |

> **Límite:** son datos sintéticos. Estas métricas comprueban que el pipeline funciona de punta a
> punta, pero **no validan** la hipótesis del proyecto (F1 ≥ 0,80). El generador no se ajustó para
> subir las métricas. Validar la hipótesis requiere datos reales de finca (planificado en #96).

### Evaluación del modelo desplegado (datos SINTÉTICOS, sin validez clínica)

`ml/src/evaluate_lstm.py` evalúa `mastitis_lstm.tflite` (el archivo de la app, sin reentrenarlo) con
la misma partición por vaca. Intervalos al 95 % por bootstrap de vacas. Detalle y tablas completas en
`ml/README.md` y `ml/reports/lstm_evaluation.json`. Pruebas: `test_lstm_evaluation.py`,
`test_lstm_evaluation_limits.py` y `test_evaluate_lstm_main.py`.

| Pregunta | Resultado |
|---|---|
| ¿Supera a líneas base simples? | Sí al umbral de temperatura (F1 0,49 vs. 0,33; ΔAUC −0,10 a −0,03). Frente a la regresión logística (F1 0,43) y al random forest (F1 0,44) la ventaja es chica: en AUC es significativa (~0,02–0,03) y en F1 contra el random forest no |
| ¿Aguanta ruido de medición? | Con el ruido diario normal duplicado el F1 baja de 0,49 a 0,26 (AUC 0,78) por falsas alarmas |
| ¿Aguanta datos faltantes? | Con 30 % de celdas vacías solo el 18 % de las ventanas llega al modelo; las evaluadas mantienen el AUC (0,85) |
| ¿Y si faltan los últimos días? | **Es el punto más débil.** El relleno con el último valor borra la señal: con 2 días sin registro F1 0,16, con 4 días AUC 0,52 |
| ¿Funciona en otra finca? | Con otras vacas de la misma finca simulada, igual (F1 0,51). Con más estrés calórico o registros ruidosos el umbral fijo alerta al 90–96 % de las vacas sanas. Con todos los cambios juntos, AUC 0,63 y F1 0,13 |
| ¿La salida es una probabilidad? | No. ECE 0,245: entre 0,8 y 0,9 solo el 22 % de las ventanas es de riesgo. Es un puntaje |
| ¿Son estables los umbrales 0,427 / 0,854? | El F1 varía entre 0,47 y 0,51 con el rojo de 0,80 a 0,93; el costo es que 31 de 58 vacas sanas reciben alguna alerta roja (19 con 0,90) |
| ¿Qué variables usa? | Las tres. Caída del AUC al permutar: temperatura 0,12, leche 0,08, alimento 0,04. Esto refleja el simulador, no la fisiología |

> **Límite:** todo sale del mismo generador sintético, incluidas las "otras fincas". Sirve para
> encontrar debilidades del pipeline (días recientes faltantes, umbral que no se traslada entre
> fincas, salida no calibrada), no para afirmar validez clínica. No se cambió el modelo ni la app.

## 2. Datasets públicos revisados

| Dataset | Uso | Decisión |
|---|---|---|
| Ubres, Roboflow `mastitis-zmser` v1 (CC BY 4.0), 124 fotos | CNN de triaje visual | Usado, con limpieza y agrupación por vaca |
| Leche en paleta, Roboflow `mastitis-dataset` v3 (CC BY 4.0), 453 imágenes y 640 pocillos | Clasificador de leche (evaluación 5 × 5) | No se integra en la app: el contexto solo da AUC 0,91 |
| Series IoT, Mendeley DOI 10.17632/kbvcdw5b4m.2 (CC BY 4.0) | LSTM | **Descartado**: no tiene leche ni alimento, solo 6 días por vaca (el modelo usa 14), la etiqueta es idéntica a la variable de leche anormal y la temperatura está fuera del rango fisiológico |

Validaciones aplicadas al dataset de ubres (`ml/tests/test_udder_public_data.py`, 10 pruebas):

- Se descartaron 7 fotos cuyo recorte medía menos de 96 px; quedaron 117 (56 sanas y 61 con mastitis).
- Agrupación por vaca o escena con hash perceptual y revisión manual (22 uniones a mano): 71 grupos
  independientes, para que la misma ubre no quede a la vez en entrenamiento y en prueba.
- Se encontraron dos grupos con etiquetas contradictorias para la misma ubre (img-105 «Moderate» y
  img-107 «No»; img-51 e img-53). Las etiquetas son del autor del dataset, sin confirmación veterinaria.

## 3. CNN de ubre (sana vs. mastitis)

Validación cruzada 5 × 5 agrupada por vaca, umbral 0,5, con intervalos de confianza al 95 %:

| Experimento | Sensibilidad | Especificidad | AUC |
|---|---|---|---|
| Todas las fotos | 0,77 (0,65–0,86) | 0,89 (0,79–0,95) | 0,87 (0,76–0,96) |
| El mismo modelo evaluado solo en el establo | 0,58 (0,41–0,74) | 0,89 (0,78–0,95) | 0,76 (0,58–0,92) |
| Entrenado y evaluado solo en el establo | 0,55 (0,38–0,71) | 0,91 (0,80–0,96) | 0,81 (0,65–0,94) |
| **Solo el fondo, con la ubre tapada** | 0,74 | 0,70 | **0,75 (0,62–0,87)** |

Matriz de confusión del modelo principal: VN 50 · FP 6 · FN 14 · VP 47.

**Conclusión:** hay **sesgo de fondo**. El potrero, el cielo y las marcas de agua solo aparecen en
fotos con mastitis, y un modelo que solo ve el fondo acierta muy por encima del azar. En un mismo
establo se escapa casi la mitad de las mastitis. Por eso la CNN queda **apagada** en la app
(`--dart-define=UDDER_TRIAGE=true` para encenderla) y fuera del APK por defecto.

Exportación: MobileNetV2 alpha 0.35 en float16 (870 KB). Frente a Keras, en las 117 fotos la
diferencia máxima es 0,024 y la media 0,006; cambian 2 decisiones, las dos justo en el umbral. La
tolerancia de la prueba de paridad se fijó en 0,01 y **se subió a 0,03 después de ver el resultado**;
está declarado en `ml/README.md`.

Para validarla hacen falta fotos reales confirmadas por un veterinario, al menos 50 por clase (#95, #11).

## 4. Clasificador de leche normal o anormal (evaluación, no se integra en la app)

**Dataset:** abdurrehman4198, *Mastitis dataset* v3, Roboflow Universe, 2026,
https://universe.roboflow.com/abdurrehman4198-gmail-com/mastitis-dataset, licencia **CC BY 4.0**.
Son 453 imágenes y 640 pozos (189 normales; 184 con sangre, 151 aguados, 116 con grumos).

Validaciones del dataset (`ml/tests/test_milk_data.py`):

- **El split original filtra datos.** 41 grupos de frames casi idénticos estaban en más de un split de
  Roboflow. Por eso no se usa.
- **Grupos.** Se unen los casi duplicados (pHash y dHash) y las fotos PXL de la misma sesión (dos
  sesiones del 26-05-2026: 12 fotos de 03:26 a 03:32 y 39 de 03:43 a 04:08). Quedan 163 grupos; el
  mayor tiene 75 pozos.
- **Cada escena tiene una sola clase.** 155 de los 163 grupos tienen una sola clase.
- **Etiquetas.** No hay contradicciones entre frames casi idénticos (mismo pozo con grados distintos).

Validación `StratifiedGroupKFold` 5 × 5, umbral 0,5, con intervalos de confianza al 95 %:

| Experimento | Sensibilidad (Wilson · bootstrap por grupos) | Especificidad (Wilson · bootstrap por grupos) | AUC (bootstrap por grupos) |
|---|---|---|---|
| MobileNetV2 | 0,978 (0,960–0,988 · 0,949–0,997) | 1,000 (0,980–1,000 · 1,000–1,000) | 0,9996 (0,9986–1,0000) |
| MobileNetV3-Small | 0,987 (0,971–0,994 · 0,969–0,998) | 0,984 (0,954–0,995 · 0,957–1,000) | 0,9996 (0,9985–1,0000) |
| **Solo el contexto, sin ninguna leche** | 0,931 | 0,683 | **0,912 (0,852–0,959)** |
| Sin la sesión PXL, evaluada solo en ella | 1,000 (0,862–1,000) | 1,000 (0,959–1,000) | 1,000 |

- **Arquitecturas:** diferencia de AUC 0,0001 (IC pareado −0,0009 a 0,0011), no hay una mejor.
  Afinar no mejora sobre la red congelada.
- **Matriz por grado** (MobileNetV2): sangre 184/184, aguada 151/151, grumos 106/116 detectados;
  0/189 normales marcados. Los errores son grumos casi lisos.
- **Calibración:** ECE de 0,020 (V2) y 0,019 (V3-Small). En la zona media el modelo predice menos
  riesgo del real (`ml/informes/calibracion.png`).
- **Robustez:** la luz y la rotación casi no la afectan. Con desenfoque fuerte o JPEG de calidad 10 la
  especificidad cae hasta 0,27–0,51: falsas alarmas con fotos movidas o muy comprimidas.
- **TFLite float16:** 857 KB; 3,3 ms con 1 hilo en el CPU del PC (no se midió en un celular);
  diferencia máxima con Keras de 0,021, sin decisiones cambiadas.

**Conclusión: hay sesgo de contexto.** Sin ver ninguna leche, la red llega a AUC 0,91. El resultado
casi perfecto viene de un dataset con una sola paleta, un tipo de celular y escenas de una sola clase,
y no se puede atribuir solo al aspecto de la leche. Además, el aspecto anormal de la leche es un signo
de **mastitis clínica**; la subclínica no se ve y esto no detecta infección en general. Por eso **no se
integra en la app**. Detalle en `ml/README.md` y `ml/reports/milk_cnn.json`; figuras en `ml/informes/`.

## 5. Reglas del puntaje por síntomas

Las reglas de `docs/symptom_score.md` y las equivalencias del registro por preguntas están marcadas
como **provisionales** en la app y en la documentación. La revisión con un veterinario está
planificada en #92.
