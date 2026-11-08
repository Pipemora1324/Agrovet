# Puntaje por síntomas y semáforo combinado

> **Reglas provisionales, a validar con un veterinario.** No son un diagnóstico ni salen de un estudio
> clínico: se escribieron para que la app pueda alertar con lo que el ganadero ve, aunque no tenga
> termómetro ni registre la leche todos los días. La app muestra este aviso junto al puntaje.

## Por qué existe

El modelo LSTM necesita varios días seguidos con temperatura, leche y alimento. Muchos ganaderos no
toman esas medidas a diario, pero sí ven la ubre y la leche en cada ordeño. El puntaje convierte esas
observaciones en un color del semáforo con reglas que cualquiera puede revisar.

## Reglas

Se aplican al **registro del día** que se evalúa. Cada señal suma una vez.

| Señal | Puntos | Motivo |
|---|---|---|
| Grumos o sangre en la leche | 3 | Cambio visible de la leche: signo central de mastitis clínica. |
| Ubre hinchada | 2 | Inflamación. |
| Ubre caliente | 2 | Inflamación. |
| Dolor al tocar la ubre | 2 | Inflamación. |
| Fiebre: 39,5 °C o más (si se midió) | 2 | Respuesta general a la infección. |
| Ubre enrojecida | 1 | Inflamación; por sí sola es un signo débil. |
| Dio menos leche de lo usual | 1 | Señal temprana, pero tiene muchas otras causas. |
| No comió normal (o la casilla anterior "decaída") | 1 | Señal general de que la vaca no está bien. |

| Puntaje | Color |
|---|---|
| 0 a 1 | Verde |
| 2 a 3 | Amarillo |
| 4 o más | Rojo |

Con estas reglas, un solo signo claro de la ubre o de la leche ya pone el semáforo en amarillo, y dos
signos juntos (por ejemplo, grumos y ubre caliente) lo ponen en rojo. Las señales generales (menos
leche, no comió) solo suben el color si se suman a otras.

Las preguntas sin responder no suman. "Comió normal: sí" y "Dio menos leche: no" tampoco.

## Semáforo final

1. **Modelo**: si en los últimos 14 días hay suficientes días con temperatura, leche y alimento (los
   que pide `min_valid_days` en `ml/models/model_config.json`), el LSTM da una probabilidad y su color.
   Si no, la pantalla dice "Faltan datos para el modelo" y cuántos días hay.
2. **Síntomas**: si hay registro del día, se calcula el puntaje.
3. **Color final**: el más grave de los dos. La pantalla dice quién lo indicó: "el modelo", "los
   síntomas" o "los síntomas y el modelo" (si dieron el mismo color).
4. Sin registro del día y sin datos para el modelo, no hay evaluación: la app pide hacer el registro.

Cada evaluación se guarda con la probabilidad (si hubo modelo), el puntaje (si hubo registro) y la
causa; se sincroniza con el servidor (`inferences.symptom_score` y `inferences.cause`). Si no se usó el
modelo, `model_version` guarda la versión de las reglas (`sintomas-provisional-1`).

## Dónde está

- Reglas: `mobile/lib/domain/symptom_score.dart` (`SymptomScore.rules`).
- Combinación: `RiskEvaluator.combine` en `mobile/lib/domain/risk_evaluator.dart`.
- Pruebas: `mobile/test/domain/symptom_score_test.dart`.

Si un veterinario propone otros puntos o umbrales, se cambian en `SymptomScore`, se sube
`SymptomScore.version` y se actualiza esta tabla.
