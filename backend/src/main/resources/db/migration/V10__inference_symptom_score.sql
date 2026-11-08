-- El semáforo final combina el modelo LSTM y un puntaje por síntomas (reglas provisionales).
-- Sin días suficientes con datos numéricos el modelo no se usa: la probabilidad queda vacía.
ALTER TABLE inferences ALTER COLUMN probability DROP NOT NULL;

ALTER TABLE inferences
    ADD COLUMN symptom_score INTEGER     CHECK (symptom_score BETWEEN 0 AND 30),
    -- Qué indicador fijó el color final. NULL en evaluaciones anteriores (solo modelo).
    ADD COLUMN cause         VARCHAR(10) CHECK (cause IN ('MODEL', 'SYMPTOMS', 'BOTH'));

-- Toda evaluación debe tener al menos uno de los dos indicadores
ALTER TABLE inferences ADD CONSTRAINT ck_inferences_has_indicator
    CHECK (probability IS NOT NULL OR symptom_score IS NOT NULL);
