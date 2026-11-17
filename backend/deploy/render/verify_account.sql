-- Marca como verificado el correo de una cuenta nueva en el servidor de demostración de Render,
-- donde el código de verificación no puede salir (el plan gratuito bloquea el SMTP).
-- Se ejecuta con verify_account.ps1; el correo llega por la variable de entorno ACCOUNT_EMAIL.
\set ON_ERROR_STOP on
\getenv email ACCOUNT_EMAIL

UPDATE users SET email_verified = TRUE, updated_at = now()
WHERE email = lower(:'email') AND email_verified = FALSE;

SELECT email, email_verified FROM users WHERE email = lower(:'email');
