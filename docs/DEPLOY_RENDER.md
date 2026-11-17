# Plan: servidor de demostración en Render (plan gratuito)

> **Estado: plan, no desplegado.** Nada de esto se ha ejecutado en Render. Las cifras de memoria y
> tiempo salen de una prueba local que imita el plan gratuito (Docker con `--memory=512m --cpus=0.1`,
> 2026-11-17). Render puede comportarse distinto: hay que medir de nuevo después del primer despliegue.

Objetivo: un servidor **de demostración** para que la app funcione con cuenta real (ingreso, datos
desde la base, asistente con Gemini y sincronización) mientras no haya un servidor propio (ver
[DEPLOY.md](DEPLOY.md) para el servidor definitivo). Los datos son sintéticos.

## Resumen

| Pregunta | Respuesta |
|---|---|
| ¿Cabe en 512 MB? | Sí. La API usó 217–242 MiB en la prueba local, con 512 MB de límite. |
| ¿Funciona el ingreso con la cuenta de demostración? | Sí. El usuario se crea ya verificado con el script de datos de demostración. |
| ¿Funciona el registro de cuentas nuevas? | **Solo a medias.** El plan gratuito bloquea el SMTP (puertos 25, 465 y 587): el código de verificación nunca llega. La salida más simple es verificar a mano cada cuenta nueva con una línea de SQL. |
| ¿Funcionan las vacas, el historial y la sincronización? | Sí (probado en local contra la misma imagen). |
| ¿Funciona el asistente? | Sí, si se define `GEMINI_API_KEY`. La salida a Gemini es HTTPS (puerto 443), que no está bloqueado. Sin clave responde 503 y la app muestra consejos fijos. |
| Arranque en frío | Render dice que despertar el servicio toma "about one minute", pero eso no incluye arrancar Spring Boot. **En la prueba local con 0,1 de CPU, la API tardó 147 s en arrancar** (ajustes de abajo) y 197 s sin ajustes. Hay que despertarla unos 3 minutos antes de una demostración. |
| ¿Se pierde algo? | Las **fotos** (no hay disco persistente: se borran cuando el servicio se duerme) y, a los 30 días, **la base de datos** completa. |

## Límites del plan gratuito que importan aquí

De la documentación de Render ([render.com/docs/free](https://render.com/docs/free) y
[render.com/docs/compute-plans](https://render.com/docs/compute-plans)), leída el 2026-11-17:

- Servicio web: **512 MB y 0,1 CPU**. Se duerme tras **15 minutos** sin tráfico entrante; al
  despertar se pierde lo escrito en su disco local. 750 horas gratis al mes por espacio de trabajo
  (un solo servicio encendido todo el mes usa 744).
- "Free web services can't send outbound network traffic on ports `25`, `465`, or `587`, commonly
  used for SMTP."
- Sin disco persistente, sin Shell/SSH y sin tareas puntuales (*one-off jobs*).
- Postgres gratuito: 1 GB, 0,1 CPU y 256 MB. **Vence a los 30 días de creado**; luego hay 14 días
  para pasarlo a un plan pago y después se borra con todos sus datos. Sin copias de seguridad. Una
  base gratuita por espacio de trabajo.
- Render asigna `PORT=10000` por defecto y deja cambiarlo con la variable `PORT`.

## Medición local (imita el plan gratuito)

Imagen construida con `backend/Dockerfile` tal como está. Postgres 15 en otro contenedor con
`--memory=256m --cpus=0.1`. API con `--memory=512m --memory-swap=512m --cpus=0.1`, perfil `prod`.

| Configuración de la JVM | Arranque (log "Started …") | Memoria al arrancar | Primer ingreso |
|---|---|---|---|
| Sin ajustes | 197 s | 242 MiB | — |
| `JAVA_TOOL_OPTIONS` (abajo) | **147 s** | 218 MiB | 16 s |
| Lo mismo + `SPRING_MAIN_LAZY_INITIALIZATION=true` | 141 s | 217 MiB | 29 s |

Con el servicio ya despierto: ingreso 4,6 s y `GET /api/cows` 0,8 s. El ingreso es lento porque
BCrypt (costo 12) con 0,1 de CPU tarda varios segundos; está dentro del tiempo de espera de la app
(30 s).

Se recomienda solo los ajustes de la JVM; la inicialización perezosa no ahorra tiempo total:

```
JAVA_TOOL_OPTIONS=-XX:MaxRAMPercentage=70 -XX:+UseSerialGC -XX:TieredStopAtLevel=1 -Xss512k
```

## Correo y registro

El backend exige verificar el correo antes de ingresar (403 `EMAIL_NOT_VERIFIED`), y en Render
gratuito el correo no puede salir. Además, el perfil `prod` no arranca sin `MAIL_USERNAME` y
`MAIL_PASSWORD` (`require-smtp: true`).

En la prueba local con el correo sin salida, el registro respondió 202 y el envío falló en segundo
plano (`AccountMailer: No se pudo enviar el correo …`), sin afectar la API.

Opciones, de la más simple a la más trabajosa:

1. **Recomendada para la demostración (sin cambiar código):**
   - Se ingresa con el usuario de demostración que crea el script de abajo (ya verificado).
   - Si alguien se registra en la demostración, se verifica a mano desde el PC con el comando de
     "Verificar a mano una cuenta nueva" (abajo). Probado en local: después de eso el ingreso
     responde 200.
   - "Olvidé mi contraseña" tampoco funciona, porque también envía un código.
   - `MAIL_USERNAME` y `MAIL_PASSWORD` se llenan con valores que no son credenciales (por ejemplo
     `sin-correo@agrovet.invalid` y `no-aplica`), solo para que el perfil `prod` arranque. **No** se
     pone la clave de Gmail: no serviría y quedaría en otro servidor.
2. **Enviar el correo por una API HTTPS (puerto 443)**, por ejemplo Brevo o Resend. Exige cambiar
   `AccountMailer` y depender de un servicio externo nuevo. **No está hecho; requiere su decisión.**
3. **Una bandera que apague la verificación en la demostración.** Toca la seguridad del registro.
   **No está hecho; requiere su decisión.**
4. Pasar el servicio web a un plan pago: Render permite 465 y 587 en planes pagos, y funcionaría el
   Gmail actual. No es gratuito.

## Archivos para Render

El `Dockerfile` del backend sirve sin cambios (compila con el JDK 21 y corre con el JRE 21, con un
usuario sin privilegios). Este `render.yaml` es una **propuesta**: no está en la raíz del repositorio
para que Render no lo tome solo. Para usarlo, cópielo a la raíz como `render.yaml` (o cree los
recursos a mano con los pasos de abajo).

```yaml
# Propuesta de Blueprint (no aplicada). Región igual para la API y la base: la API usa la dirección
# interna de la base.
databases:
  - name: agrovet-db
    plan: free
    region: virginia
    postgresMajorVersion: "15"
    databaseName: agrovet
    user: agrovet

services:
  - type: web
    name: agrovet-api
    runtime: docker
    plan: free
    region: virginia
    rootDir: backend
    dockerfilePath: ./Dockerfile
    dockerContext: .
    branch: main
    autoDeploy: false
    healthCheckPath: /actuator/health/readiness
    envVars:
      - key: SPRING_PROFILES_ACTIVE
        value: prod
      - key: PORT
        value: "8080"
      - key: JAVA_TOOL_OPTIONS
        value: -XX:MaxRAMPercentage=70 -XX:+UseSerialGC -XX:TieredStopAtLevel=1 -Xss512k
      - key: PHOTO_STORAGE_DIR
        value: /tmp/photos
      - key: DB_USERNAME
        fromDatabase: { name: agrovet-db, property: user }
      - key: DB_PASSWORD
        fromDatabase: { name: agrovet-db, property: password }
      # Se llenan a mano en el panel (sync: false = Render los pide al crear)
      - key: DB_URL
        sync: false
      - key: JWT_SECRET
        sync: false
      - key: MAIL_USERNAME
        sync: false
      - key: MAIL_PASSWORD
        sync: false
      - key: GEMINI_API_KEY
        sync: false
```

`DB_URL` va a mano porque Spring necesita el formato JDBC y Render entrega
`postgresql://usuario:clave@host/base`.

## Variables de entorno (lista exacta)

Todas se ponen en el panel de Render, en el servicio `agrovet-api`, pestaña *Environment*. Ninguna
va al repositorio.

| Variable | Valor | ¿Secreto? |
|---|---|---|
| `SPRING_PROFILES_ACTIVE` | `prod` | No |
| `PORT` | `8080` (el puerto de Spring; Render enruta ahí) | No |
| `JAVA_TOOL_OPTIONS` | `-XX:MaxRAMPercentage=70 -XX:+UseSerialGC -XX:TieredStopAtLevel=1 -Xss512k` | No |
| `PHOTO_STORAGE_DIR` | `/tmp/photos` (se borra al dormirse; ver límites) | No |
| `DB_URL` | `jdbc:postgresql://<Hostname interno>:5432/agrovet` (el *Hostname* de la sección *Connections* de la base; empieza con `dpg-`) | No, pero no conviene publicarlo |
| `DB_USERNAME` | El *Username* de la base (`agrovet`) | No |
| `DB_PASSWORD` | El *Password* de la base | **Sí** |
| `JWT_SECRET` | Base64 de al menos 32 bytes, generado al azar: `openssl rand -base64 48` | **Sí** |
| `MAIL_USERNAME` | `sin-correo@agrovet.invalid` (opción 1: no es una credencial) | No |
| `MAIL_PASSWORD` | `no-aplica` (opción 1: no es una credencial) | No |
| `GEMINI_API_KEY` | Su clave de Google AI Studio | **Sí** |

Opcionales (tienen valor por defecto en `application.yml`): `GEMINI_MODEL`
(`gemini-3.1-flash-lite`), `ASSISTANT_MAX_PER_HOUR` (20), `ASSISTANT_MAX_PER_DAY` (60), `JWT_ACCESS_TTL`
(PT15M), `JWT_REFRESH_TTL` (P14D), `CORS_ALLOWED_ORIGINS` (vacío: la app Android no usa CORS).

## Datos de demostración (sintéticos)

Un usuario verificado y 6 vacas (`DEMO-01` a `DEMO-06`, como la demostración de la app) con hasta 30
días de registros. Una vaca (Canela) tiene 6 días de subida de temperatura y caída de leche simulada.
La contraseña la elige quien ejecuta el script y Postgres la convierte en un hash BCrypt (`pgcrypto`);
no queda escrita en ningún archivo. Si el correo ya existe, falla sin cambiar nada.

Se corre **desde su PC** con la *External Database URL* (sección *Connections* de la base), porque el
plan gratuito no tiene Shell. Con Docker no hace falta instalar psql. Desde PowerShell, en la carpeta
donde guardó el script como `seed_demo.sql`:

```powershell
Get-Content seed_demo.sql | docker run --rm -i postgres:15-alpine psql "<External Database URL>?sslmode=require" `
  -v email=demo@su-correo.co -v name="Ganadero demo" -v password="<clave de 8 o más caracteres>" -f -
```

Debe terminar con una fila `demo@su-correo.co | 6 | 126`. Probado en local (2026-11-17): 6 vacas y
126 registros; con ese usuario el ingreso, `GET /api/cows`, el historial y `POST /api/sync`
respondieron 200.

```sql
-- seed_demo.sql — datos de demostración SINTÉTICOS: un usuario verificado y 6 vacas.
\set ON_ERROR_STOP on
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
    VALUES (gen_random_uuid(), :'name', lower(:'email'), crypt(:'password', gen_salt('bf', 12)),
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
```

### Verificar a mano una cuenta nueva

```powershell
docker run --rm postgres:15-alpine psql "<External Database URL>?sslmode=require" `
  -c "UPDATE users SET email_verified = TRUE WHERE email = lower('correo@de-la-persona.co');"
```

Debe responder `UPDATE 1`.

## APK que apunta al servidor

La dirección entra solo por `--dart-define=API_BASE_URL` (en release debe ser HTTPS; Render da
`https://<nombre>.onrender.com`). Desde `mobile/`:

```bash
flutter build apk --release --split-per-abi --target-platform android-arm64 \
  --dart-define=API_BASE_URL=https://agrovet-api.onrender.com \
  --dart-define=DEMO_MODE=true --dart-define=UDDER_TRIAGE=true
```

- **Respaldo sin servidor:** con `DEMO_MODE=true`, el mismo APK sigue ofreciendo "Entrar a la
  demostración", que funciona sin internet y sin servidor. Si Render está dormido, vencido o caído,
  la presentación sigue con la demostración local.
- **APK sin servidor:** conviene guardar también el APK actual, sin `API_BASE_URL`. Con esa
  variable vacía, la app no intenta conectarse y lo dice en el ingreso.
- Use nombres de archivo distintos para no confundirlos; por ejemplo:
  - `agrovet-demo-render-arm64.apk`;
  - `agrovet-demo-sin-servidor-arm64.apk`.
- Si el servicio se renombra, la URL cambia y hay que recompilar el APK.

## Arranque en frío: cómo manejarlo

- La app espera hasta 10 s para conectar y 30 s por la respuesta. Si el servicio está dormido
  (≈2,5–3,5 min hasta responder, según la medición local), el primer ingreso falla con un mensaje de
  conexión. La sincronización pendiente se reintenta sola más tarde.
- Antes de una demostración, abra en el navegador
  `https://agrovet-api.onrender.com/actuator/health` y espere a ver `{"status":"UP"…}` (unos 3 min).
  Después, el servicio queda despierto mientras reciba tráfico cada menos de 15 minutos.
- Mantenerlo despierto con un servicio externo que lo llame cada 14 min cabría en las 750 horas
  gratuitas, pero agrega otro servicio externo. **No se recomienda sin su decisión.**

## Pasos que debe hacer usted en Render

1. Crear la cuenta en render.com (el plan gratuito no pide tarjeta) y conectar GitHub dando acceso
   solo al repositorio `Agrovet`.
2. **New > Postgres:**
   - nombre `agrovet-db`;
   - *Database* `agrovet`, *User* `agrovet`;
   - región **Virginia** (la más cercana a Colombia de las disponibles);
   - versión 15, plan **Free**.
3. **Anotar las fechas:** el día de creación y la de vencimiento (+30 días), y el plazo de gracia
   (+14 días después de vencer).
4. **New > Web Service**, desde el repositorio `Agrovet`:
   - rama `main`, *Root Directory* `backend`, *Runtime* Docker;
   - *Instance type* **Free** y la **misma región** que la base;
   - *Health Check Path* `/actuator/health/readiness`;
   - *Auto-Deploy* apagado.
5. En *Environment*, poner las variables de la tabla. `JWT_SECRET` se genera en el PC con
   `openssl rand -base64 48`; en PowerShell sin openssl:
   `[Convert]::ToBase64String((1..48 | % { Get-Random -Max 256 }) -as [byte[]])`.
6. **Primer despliegue:** *Manual Deploy > Deploy latest commit*.
   - Esperar en *Logs* a ver `Successfully applied 13 migrations` y `Started AgrovetApplication`.
   - Abrir `https://<servicio>.onrender.com/actuator/health`: debe decir `UP`.
   - Anotar cuánto tardó el arranque, para comparar con los 147 s de la medición local.
7. Cargar los datos de demostración desde su PC con el comando de la sección anterior.
8. **Probar con el APK** compilado con la URL:
   - ingresar con el usuario de demostración y ver las 6 vacas;
   - crear un registro y sincronizar;
   - preguntar al asistente.
9. **Revisar la IP en los logs:**
   - El perfil `prod` toma la IP real del cliente de `X-Forwarded-For`, pero solo si el proxy tiene
     una dirección de red interna.
   - Si Render usa otras direcciones, todos los ingresos parecerán venir de la misma IP. Entonces el
     límite de 30 intentos por IP en 5 minutos sería compartido.
   - Basta con fijarse si los avisos de "demasiados intentos" aparecen con poco uso.
10. **Antes del vencimiento:** pasar la base a un plan pago, o aceptar que se borre. Después hay que
    crear otra base, cambiar `DB_URL` y `DB_PASSWORD`, volver a desplegar y volver a cargar los datos
    de demostración.

## Lo que no cubre este plan

- Correo real (registro y recuperación con código): ver las opciones 2 a 4 de "Correo y registro".
- Fotos persistentes: en esta demostración se pierden cuando el servicio se duerme. Para guardarlas
  haría falta un disco (plan pago) o un almacenamiento de objetos.
- Copias de seguridad: el Postgres gratuito no las tiene.
- No es el servidor definitivo. Ese es el de [DEPLOY.md](DEPLOY.md): VPS con Docker Compose, HTTPS
  con Caddy y SMTP real.
