-- Datos de DEMOSTRACIÓN SINTÉTICOS para el servidor de Render: un usuario verificado y 6 vacas
-- (DEMO-01 a DEMO-06, como la demostración de la app) con hasta 30 días de registros.
-- No son datos reales y no sirven para evaluar el modelo.
--
-- Se ejecuta con seed_demo.ps1, que pide la clave sin mostrarla. El correo, el nombre y la clave
-- llegan por variables de entorno (DEMO_EMAIL, DEMO_NAME, DEMO_PASSWORD), nunca en este archivo.
-- Postgres guarda solo el hash BCrypt (pgcrypto, costo 12, el mismo del backend).
-- Si el correo ya existe, falla y no cambia nada.
\set ON_ERROR_STOP on
\getenv email DEMO_EMAIL
\getenv name DEMO_NAME
\getenv password DEMO_PASSWORD

SELECT (length(:'password') BETWEEN 8 AND 72) AS password_ok,
       (:'email' ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$') AS email_ok,
       (length(trim(:'name')) > 0) AS name_ok \gset
\if :password_ok
\else
  \echo 'La contraseña debe tener entre 8 y 72 caracteres.'
  \quit 3
\endif
\if :email_ok
\else
  \echo 'El correo no es válido.'
  \quit 3
\endif
\if :name_ok
\else
  \echo 'Falta el nombre.'
  \quit 3
\endif

BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

WITH params (tag, name, breed, birth_date, calvings, status, base_t, base_m, base_f, days, sick_days, k) AS (
    VALUES ('DEMO-01', 'Lucero',   'Holstein', DATE '2021-03-10', 2, 'LACTATING', 38.6, 14.0, 11.0, 30, 0, 1),
           ('DEMO-02', 'Canela',   'Normando', DATE '2020-07-22', 3, 'LACTATING', 38.5, 12.0, 10.0, 30, 6, 2),
           ('DEMO-03', 'Mariposa', 'Jersey',   DATE '2022-01-05', 1, 'LACTATING', 38.7, 10.0,  9.0, 30, 0, 3),
           ('DEMO-04', 'Estrella', 'Holstein', DATE '2019-11-30', 4, 'LACTATING', 38.6, 16.0, 12.0, 30, 0, 4),
           ('DEMO-05', 'Paloma',   'Criolla',  DATE '2021-09-14', 2, 'LACTATING', 38.4,  8.0,  8.0,  6, 0, 5),
           ('DEMO-06', 'Luna',     'Normando', DATE '2020-04-02', 3, 'DRY',       38.5,  0.0, 10.0,  0, 0, 6)
),
owner AS (
    INSERT INTO users (id, name, email, password_hash, created_at, updated_at, email_verified,
                       privacy_policy_version, privacy_accepted_at)
    VALUES (gen_random_uuid(), trim(:'name'), lower(:'email'), crypt(:'password', gen_salt('bf', 12)),
            now(), now(), TRUE, '2026-11', now())
    RETURNING id
),
cows_in AS (
    INSERT INTO cows (id, owner_id, tag, name, breed, birth_date, calvings, production_status, created_at, updated_at)
    SELECT gen_random_uuid(), owner.id, p.tag, p.name, p.breed, p.birth_date, p.calvings, p.status, now(), now()
    FROM owner, params p
    RETURNING id, tag
)
INSERT INTO daily_records (id, cow_id, record_date, temperature_c, milk_l, feed_kg, abnormal_milk, notes,
                           temperature_source, milk_source, feed_source, created_at, updated_at)
SELECT gen_random_uuid(), c.id, current_date - d.ago,
       -- Variación diaria fija (seno) y, en los últimos sick_days, una fase subclínica simulada
       round((p.base_t + 0.12 * sin(d.ago * 1.7 + p.k)
              + CASE WHEN d.ago < p.sick_days THEN 0.9 * (p.sick_days - d.ago)::numeric / p.sick_days ELSE 0 END)::numeric, 1),
       CASE WHEN p.status = 'DRY' THEN NULL ELSE
       round((p.base_m * (1 + 0.04 * sin(d.ago * 2.3 + p.k))
              * (1 - CASE WHEN d.ago < p.sick_days THEN 0.22 * (p.sick_days - d.ago)::numeric / p.sick_days ELSE 0 END))::numeric, 1) END,
       round((p.base_f * (1 + 0.05 * sin(d.ago * 1.1 + p.k))
              * (1 - CASE WHEN d.ago < p.sick_days THEN 0.15 * (p.sick_days - d.ago)::numeric / p.sick_days ELSE 0 END))::numeric, 1),
       p.sick_days > 0 AND d.ago = 0,
       'Dato de demostración (sintético)',
       'measured', CASE WHEN p.status = 'DRY' THEN NULL ELSE 'measured' END, 'measured',
       now(), now()
FROM cows_in c
JOIN params p ON p.tag = c.tag
CROSS JOIN LATERAL generate_series(0, p.days - 1) AS d(ago);

COMMIT;

SELECT u.email, count(DISTINCT c.id) AS vacas, count(r.id) AS registros
FROM users u JOIN cows c ON c.owner_id = u.id LEFT JOIN daily_records r ON r.cow_id = c.id
WHERE u.email = lower(:'email')
GROUP BY u.email;
