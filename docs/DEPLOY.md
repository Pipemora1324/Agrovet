# Despliegue del backend

Guía para levantar el backend de AgroVet en un servidor propio (VPS) con Docker Compose. Hoy el
sistema corre en local; estos pasos dejan listo el paso a un servidor sin cambiar código.

Lo que queda en el servidor:

| Servicio | Imagen | Expuesto |
|---|---|---|
| `db` | `postgres:15-alpine` | No: solo la red interna de Docker. |
| `backend` | se construye con `backend/Dockerfile` (JRE 21, usuario sin privilegios) | No: solo a Caddy. |
| `caddy` | `caddy:2.8.4-alpine` | Puertos 80 y 443, con HTTPS automático (Let's Encrypt). |

Caddy solo deja pasar `/api/*` y `/actuator/health*`; todo lo demás responde 404.

## 1. Requisitos

- Un servidor Linux con Docker Engine y el plugin `docker compose` (2 GB de RAM es suficiente).
- Un dominio o subdominio (por ejemplo `api.su-dominio.co`) con un registro DNS **A** apuntando a la
  IP pública del servidor.
- Puertos 80 y 443 abiertos en el firewall. El 22 (SSH) solo para administrar; ningún otro.
- Una cuenta de correo SMTP para enviar los códigos (Gmail con contraseña de aplicación sirve; ver
  el README principal).

## 2. Copiar el código y configurar las claves

```bash
git clone https://github.com/<usuario>/<repositorio>.git agrovet
cd agrovet/backend
cp .env.example .env
chmod 600 .env
```

Edite `.env` (nunca se sube al repositorio):

| Variable | Valor en producción |
|---|---|
| `POSTGRES_DB`, `POSTGRES_USER` | Nombres a elección. |
| `POSTGRES_PASSWORD` | Contraseña larga y aleatoria: `openssl rand -base64 32`. |
| `JWT_SECRET` | `openssl rand -base64 48` (mínimo 32 bytes; si falta o es corto, no arranca). |
| `MAIL_HOST`, `MAIL_PORT` | `smtp.gmail.com` y `587` (u otro proveedor con STARTTLS). |
| `MAIL_USERNAME`, `MAIL_PASSWORD` | Obligatorios en producción: sin ellos el backend no arranca. |
| `MAIL_FROM` | Opcional; por defecto, la misma cuenta. |
| `GEMINI_API_KEY` | Opcional; sin ella el asistente responde 503 y la app muestra consejos fijos. |
| `CORS_ALLOWED_ORIGINS` | Vacío (la app Android no usa CORS). No admite `*`. |
| `AGROVET_DOMAIN` | El dominio del paso 1, sin `https://`. |

`DB_URL`, `DB_USERNAME`, `DB_PASSWORD` y `DB_HOST_PORT` no se usan en el servidor: el Compose de
producción arma la conexión a la base por la red interna.

## 3. Levantar

```bash
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml logs -f backend
```

En el log del backend deben aparecer `The following 1 profile is active: "prod"`,
`Correo: SMTP smtp.gmail.com:587 con STARTTLS` y `Started AgrovetApplication`. Flyway aplica las
migraciones (V1 a V13) en el primer arranque.

El perfil `prod` (`backend/src/main/resources/application-prod.yml`):

- apaga Swagger y `/v3/api-docs`;
- exige SMTP real y no usa Mailpit;
- no devuelve mensajes internos ni trazas en los errores;
- no escribe consultas SQL ni correos completos en el log (los usuarios aparecen por su id);
- toma la IP real del cliente de `X-Forwarded-For` (lo pone Caddy), para el límite de intentos.

## 4. Comprobar

Chequeo de salud (sin detalles internos), listo para un monitor externo:

```bash
curl https://api.su-dominio.co/actuator/health            # {"status":"UP"}
curl https://api.su-dominio.co/actuator/health/readiness  # listo para recibir tráfico
curl https://api.su-dominio.co/actuator/health/liveness   # el proceso responde
curl -I https://api.su-dominio.co/swagger-ui.html         # 404
curl -I https://api.su-dominio.co/api/cows                # 401 (requiere sesión)
```

Docker también usa `/actuator/health/readiness` como `healthcheck` del contenedor `backend`.

## 5. Compilar la app para ese servidor

La dirección del servidor sale solo de `--dart-define=API_BASE_URL`. En release debe ser HTTPS: con
`http://` la app muestra "Configuración incompleta" y no arranca. Android también bloquea el tráfico
sin cifrar (`network_security_config.xml`).

```bash
cd mobile
flutter build apk --release --split-per-abi --dart-define=API_BASE_URL=https://api.su-dominio.co
```

## 6. Mantenimiento

Actualizar a una versión nueva:

```bash
git pull
docker compose -f docker-compose.prod.yml up -d --build
```

Copia de seguridad diaria de la base y de las fotos (por ejemplo con `cron`):

```bash
docker compose -f docker-compose.prod.yml exec -T db \
  pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom > agrovet-$(date +%F).dump
docker run --rm -v backend_photos:/fotos -v "$PWD":/copia alpine \
  tar czf /copia/fotos-$(date +%F).tar.gz -C /fotos .
```

Guarde las copias fuera del servidor y cifradas: contienen datos personales (Ley 1581 de 2012).
Para restaurar: `pg_restore -U ... -d ... --clean agrovet-AAAA-MM-DD.dump`.

## Lo que esta guía no cubre todavía

- Monitoreo y alertas (basta con un servicio externo que consulte `/actuator/health`).
- Más de una instancia del backend: los límites de intentos viven en memoria y no se comparten.
