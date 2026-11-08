-- Perfil del ganadero y registro del consentimiento (Ley 1581 de 2012).
ALTER TABLE users
    ADD COLUMN farm_name              VARCHAR(100),
    ADD COLUMN municipality           VARCHAR(80),
    ADD COLUMN phone                  VARCHAR(20),
    -- Versión del aviso de privacidad que la persona aceptó y cuándo. Las cuentas anteriores a esta
    -- versión quedan en NULL: la app les pide aceptar el aviso al abrir el perfil.
    ADD COLUMN privacy_policy_version VARCHAR(20),
    ADD COLUMN privacy_accepted_at    TIMESTAMPTZ;
