-- El id (UUID) lo genera el celular para poder crear vacas sin conexión
CREATE TABLE cows (
    id                UUID PRIMARY KEY,
    owner_id          UUID         NOT NULL REFERENCES users (id),
    tag               VARCHAR(40)  NOT NULL,
    name              VARCHAR(80),
    breed             VARCHAR(60),
    birth_date        DATE,
    calvings          INTEGER      CHECK (calvings BETWEEN 0 AND 30),
    production_status VARCHAR(20)  NOT NULL
        CHECK (production_status IN ('LACTATING', 'DRY', 'HEIFER')),
    created_at        TIMESTAMPTZ  NOT NULL,
    updated_at        TIMESTAMPTZ  NOT NULL,
    deleted           BOOLEAN      NOT NULL DEFAULT FALSE
);

CREATE INDEX ix_cows_owner ON cows (owner_id);
-- Un mismo ganadero no puede tener dos vacas activas con el mismo identificador
CREATE UNIQUE INDEX ux_cows_owner_tag ON cows (owner_id, tag) WHERE NOT deleted;
