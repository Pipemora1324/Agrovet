-- Origen de cada valor del registro diario: 'measured' (termómetro, litros o kilos exactos) o
-- 'estimated' (calculado por la app con la respuesta del ganadero y la línea base de la vaca).
-- NULL: sin valor, o registro de una versión anterior de la app (valores escritos a mano).
ALTER TABLE daily_records
    ADD COLUMN temperature_source VARCHAR(10),
    ADD COLUMN milk_source        VARCHAR(10),
    ADD COLUMN feed_source        VARCHAR(10),
    ADD CONSTRAINT daily_records_temperature_source_check CHECK (temperature_source IN ('measured', 'estimated')),
    ADD CONSTRAINT daily_records_milk_source_check CHECK (milk_source IN ('measured', 'estimated')),
    ADD CONSTRAINT daily_records_feed_source_check CHECK (feed_source IN ('measured', 'estimated'));

COMMENT ON COLUMN daily_records.temperature_source IS 'measured | estimated | NULL';
COMMENT ON COLUMN daily_records.milk_source IS 'measured | estimated | NULL';
COMMENT ON COLUMN daily_records.feed_source IS 'measured | estimated | NULL';
