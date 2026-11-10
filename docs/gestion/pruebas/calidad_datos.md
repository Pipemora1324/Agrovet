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

## 2. Datasets públicos revisados

| Dataset | Uso | Decisión |
|---|---|---|
| Ubres, Roboflow `mastitis-zmser` v1 (CC BY 4.0), 124 fotos | CNN de triaje visual | Usado, con limpieza y agrupación por vaca |
| Leche en paleta, Roboflow `mastitis-dataset` v3 (CC BY 4.0), 453 imágenes y 640 pocillos | Prueba de concepto | No se integra en la app |
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

## 4. Prueba de concepto: pocillos de leche

640 pocillos en 200 grupos, validación 5 × 1: sensibilidad 0,96, especificidad 1,00, AUC 0,999.
Sin la sesión PXL y evaluada solo en ella: 113 de 113 aciertos. **Límite:** la tarea es fácil en
estas condiciones (misma paleta, suelo y luz), las etiquetas no tienen confirmación de laboratorio
y la mastitis subclínica no cambia el aspecto de la leche. No se integra en la app.

## 5. Reglas del puntaje por síntomas

Las reglas de `docs/symptom_score.md` y las equivalencias del registro por preguntas están marcadas
como **provisionales** en la app y en la documentación. La revisión con un veterinario está
planificada en #92.
