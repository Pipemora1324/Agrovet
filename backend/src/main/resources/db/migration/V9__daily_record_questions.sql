-- Preguntas simples del registro diario y más signos de la ubre.
-- Las respuestas Sí/No pueden quedar sin contestar (NULL); los signos son casillas (FALSE si no se marcan).
-- Se conservan las columnas anteriores: udder_swelling (hinchada), udder_pain (dolor al tocar),
-- abnormal_milk (grumos o sangre en la leche) y lethargy (casilla anterior "decaída, come poco").
ALTER TABLE daily_records
    ADD COLUMN ate_normally  BOOLEAN,
    ADD COLUMN milk_drop     BOOLEAN,
    ADD COLUMN udder_redness BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN udder_heat    BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN daily_records.ate_normally IS '¿Comió normal? NULL = sin respuesta';
COMMENT ON COLUMN daily_records.milk_drop IS '¿Produjo menos leche de lo usual? NULL = sin respuesta';
