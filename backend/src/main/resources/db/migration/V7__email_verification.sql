-- Verificación de correo y recuperación de contraseña con código de 6 dígitos.
ALTER TABLE users ADD COLUMN email_verified BOOLEAN NOT NULL DEFAULT FALSE;

-- Las cuentas creadas antes de esta versión ya estaban en uso: se dan por verificadas
UPDATE users SET email_verified = TRUE;

-- Solo se guarda el HMAC del código, nunca el código. Pedir uno nuevo anula los anteriores
-- (consumed_at), y cada código admite un número limitado de intentos.
CREATE TABLE email_codes (
    id          UUID PRIMARY KEY,
    user_id     UUID        NOT NULL REFERENCES users (id),
    purpose     VARCHAR(20) NOT NULL CHECK (purpose IN ('VERIFY_EMAIL', 'RESET_PASSWORD')),
    code_hash   VARCHAR(64) NOT NULL,
    attempts    INTEGER     NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    expires_at  TIMESTAMPTZ NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ
);

CREATE INDEX ix_email_codes_user_purpose ON email_codes (user_id, purpose, created_at);
