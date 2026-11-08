-- Fotos de las vacas. Los datos viajan con la sincronización; el archivo se sube aparte y se guarda
-- en disco (PHOTO_STORAGE_DIR), ya sin metadatos.
CREATE TABLE cow_photos (
    id           UUID PRIMARY KEY,
    cow_id       UUID        NOT NULL REFERENCES cows (id),
    taken_on     DATE        NOT NULL,
    -- true cuando el archivo ya se recibió y se guardó
    stored       BOOLEAN     NOT NULL DEFAULT FALSE,
    size_bytes   INTEGER     CHECK (size_bytes > 0),
    created_at   TIMESTAMPTZ NOT NULL,
    updated_at   TIMESTAMPTZ NOT NULL,
    deleted      BOOLEAN     NOT NULL DEFAULT FALSE
);

CREATE INDEX ix_cow_photos_cow ON cow_photos (cow_id, taken_on);
