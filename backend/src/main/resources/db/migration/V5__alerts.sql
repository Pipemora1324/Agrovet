CREATE TABLE alerts (
    id           UUID PRIMARY KEY,
    cow_id       UUID        NOT NULL REFERENCES cows (id),
    inference_id UUID        REFERENCES inferences (id),
    risk_level   VARCHAR(10) NOT NULL CHECK (risk_level IN ('YELLOW', 'RED')),
    attended     BOOLEAN     NOT NULL DEFAULT FALSE,
    attended_at  TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL,
    updated_at   TIMESTAMPTZ NOT NULL,
    deleted      BOOLEAN     NOT NULL DEFAULT FALSE
);

CREATE INDEX ix_alerts_cow ON alerts (cow_id);
