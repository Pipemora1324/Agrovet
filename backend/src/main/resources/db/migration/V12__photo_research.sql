-- Datos de investigación de cada foto. Solo las fotos con consentimiento expreso (apagado por defecto)
-- y diagnóstico confirmado por un veterinario sirven para entrenar la CNN.
ALTER TABLE cow_photos
    ADD COLUMN vet_confirmed       VARCHAR(10)  CHECK (vet_confirmed IN ('YES', 'NO', 'PENDING')),
    ADD COLUMN diagnosis           VARCHAR(10)  CHECK (diagnosis IN ('MASTITIS', 'HEALTHY', 'OTHER')),
    ADD COLUMN diagnosis_notes     VARCHAR(300),
    ADD COLUMN research_consent    BOOLEAN      NOT NULL DEFAULT FALSE,
    ADD COLUMN research_consent_at TIMESTAMPTZ;
