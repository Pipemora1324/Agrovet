CREATE TABLE daily_records (
    id              UUID PRIMARY KEY,
    cow_id          UUID             NOT NULL REFERENCES cows (id),
    record_date     DATE             NOT NULL,
    temperature_c   DOUBLE PRECISION CHECK (temperature_c BETWEEN 30 AND 45),
    milk_l          DOUBLE PRECISION CHECK (milk_l BETWEEN 0 AND 80),
    feed_kg         DOUBLE PRECISION CHECK (feed_kg BETWEEN 0 AND 60),
    -- Checklist de síntomas visibles
    udder_swelling  BOOLEAN          NOT NULL DEFAULT FALSE,
    abnormal_milk   BOOLEAN          NOT NULL DEFAULT FALSE,
    udder_pain      BOOLEAN          NOT NULL DEFAULT FALSE,
    lethargy        BOOLEAN          NOT NULL DEFAULT FALSE,
    notes           VARCHAR(500),
    created_at      TIMESTAMPTZ      NOT NULL,
    updated_at      TIMESTAMPTZ      NOT NULL,
    deleted         BOOLEAN          NOT NULL DEFAULT FALSE
);

CREATE INDEX ix_daily_records_cow_date ON daily_records (cow_id, record_date);
-- Un registro activo por vaca y día
CREATE UNIQUE INDEX ux_daily_records_cow_date ON daily_records (cow_id, record_date) WHERE NOT deleted;
