CREATE TABLE inferences (
    id              UUID PRIMARY KEY,
    cow_id          UUID             NOT NULL REFERENCES cows (id),
    window_end_date DATE             NOT NULL,
    probability     DOUBLE PRECISION NOT NULL CHECK (probability BETWEEN 0 AND 1),
    risk_level      VARCHAR(10)      NOT NULL CHECK (risk_level IN ('GREEN', 'YELLOW', 'RED')),
    model_version   VARCHAR(40)      NOT NULL,
    created_at      TIMESTAMPTZ      NOT NULL,
    updated_at      TIMESTAMPTZ      NOT NULL,
    deleted         BOOLEAN          NOT NULL DEFAULT FALSE
);

CREATE INDEX ix_inferences_cow_date ON inferences (cow_id, window_end_date);
