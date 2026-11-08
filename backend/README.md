# backend — API de AgroVet

API REST en Java 21 y Spring Boot 3.5 con PostgreSQL 15. Gestiona usuarios, vacas, registros
diarios, inferencias y alertas, y recibe la sincronización por lotes desde la app.

La autenticación es propia (Spring Security): no depende de servicios externos.

## Ejecutar con Docker (recomendado)

Requiere Docker Desktop encendido.

```bash
cd backend
cp .env.example .env
# Generar un secreto propio y ponerlo en JWT_SECRET dentro de .env:
openssl rand -base64 48
docker compose up --build -d
```

- API: `http://localhost:8080`
- Documentación (Swagger): `http://localhost:8080/swagger-ui.html`
- Salud: `http://localhost:8080/actuator/health`
- Correos de prueba (Mailpit): `http://localhost:8025`. Ahí llegan los códigos de verificación y de
  recuperación; no sale ningún correo real.

Si ya tiene otro PostgreSQL usando el puerto 5432, cambie `DB_HOST_PORT` en `.env` (por ejemplo,
a 5433). Para detener: `docker compose down` (agregue `-v` para borrar también los datos).

## Ejecutar sin Docker para el backend

Con la base del docker-compose encendida (`docker compose up -d db`):

```bash
# Las variables de .env deben estar cargadas en la terminal
./mvnw spring-boot:run
```

## Pruebas

```bash
./mvnw verify
```

Las pruebas de integración levantan un PostgreSQL 15 real con Testcontainers, así que Docker debe
estar encendido.

### JDK 21 sin cambiar el Java del equipo

El `pom.xml` exige un JDK 21 mediante *Maven toolchains*. Maven puede correr con otro Java (por
ejemplo 17), pero compila y prueba con el JDK 21 registrado en `~/.m2/toolchains.xml`:

```xml
<toolchains>
  <toolchain>
    <type>jdk</type>
    <provides><version>21</version></provides>
    <configuration><jdkHome>RUTA_AL_JDK_21</jdkHome></configuration>
  </toolchain>
</toolchains>
```

En GitHub Actions, `setup-java` crea ese archivo automáticamente. Dentro de Docker se usa
`-DskipToolchain`, porque la imagen ya trae el JDK 21.

## Variables de entorno

| Variable | Uso |
|---|---|
| `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` | Conexión JDBC a PostgreSQL. |
| `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` | Base del contenedor local. |
| `DB_HOST_PORT` | Puerto del equipo donde se publica la base (5432 por defecto). |
| `JWT_SECRET` | Secreto HS256 en Base64, mínimo 32 bytes. Sin él la aplicación no arranca. |
| `JWT_ACCESS_TTL` | Vida del token de acceso (por defecto `PT15M`). |
| `JWT_REFRESH_TTL` | Vida del refresh token (por defecto `P14D`). |
| `CORS_ALLOWED_ORIGINS` | Orígenes web permitidos, separados por coma. Vacío = ninguno. |
| `LOGIN_MAX_ATTEMPTS`, `LOGIN_WINDOW`, `LOGIN_MAX_ATTEMPTS_PER_IP` | Límite de intentos de login (5 por IP y correo, 30 por IP, en 5 minutos). |
| `API_DOCS_ENABLED` | `false` para ocultar Swagger en producción. |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD` | Servidor de correo saliente. En el docker-compose, Mailpit por defecto. |
| `SMTP_AUTH`, `SMTP_STARTTLS` | `true` con un proveedor real; `false` con Mailpit. |
| `MAIL_FROM` | Remitente de los correos. Sin él la aplicación no arranca. |
| `CODE_MAX_REQUESTS_PER_IP` | Solicitudes de código por IP en una hora (20 por defecto). |

Para pasar a un servidor propio (VPS) solo cambian estas variables: el mismo código y las mismas
migraciones sirven para cualquier PostgreSQL 15.

## Endpoints

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/api/auth/register` | Crea la cuenta sin verificar y envía un código al correo (202). |
| POST | `/api/auth/verify-email` | Verifica el correo con el código y devuelve los tokens. |
| POST | `/api/auth/resend-code` | Envía otro código de verificación (espera de 60 s). |
| POST | `/api/auth/login` | Inicia sesión (con límite de intentos). Sin verificar: 403 `EMAIL_NOT_VERIFIED`. |
| POST | `/api/auth/password/forgot` | Envía un código para crear una contraseña nueva (202). |
| POST | `/api/auth/password/reset` | Cambia la contraseña con el código y cierra todas las sesiones. |
| POST | `/api/auth/refresh` | Renueva la sesión; el refresh token usado deja de servir. |
| POST | `/api/auth/logout` | Revoca la sesión. |
| GET | `/api/auth/me` | Perfil del usuario autenticado. |
| PUT | `/api/auth/me` | Edita nombre, finca, municipio y teléfono. |
| POST | `/api/auth/me/password` | Cambia la contraseña (pide la actual), cierra todas las sesiones y devuelve una nueva. |
| POST | `/api/auth/me/privacy` | Registra la aceptación del aviso de privacidad (cuentas anteriores o versión nueva). |
| DELETE | `/api/auth/me` | Elimina la cuenta y todos sus datos (pide la contraseña). |
| GET / POST | `/api/cows` | Lista o crea vacas del usuario. |
| GET / PUT / DELETE | `/api/cows/{id}` | Consulta, edita o da de baja (borrado lógico). |
| GET | `/api/cows/{id}/history?from=&to=` | Registros, inferencias y alertas (60 días por defecto). |
| POST | `/api/sync` | Lote de cambios del celular. |

## Seguridad

- **Token de acceso** JWT HS256 de 15 minutos; el sujeto es el id del usuario. Se validan firma,
  expiración y emisor.
- **Refresh token** opaco y aleatorio (32 bytes); en la base solo se guarda su hash SHA-256. Cada
  uso lo rota. Si se presenta uno ya usado, se revoca toda la sesión (detección de robo).
- **Contraseñas** con BCrypt (costo 12). Si el correo no existe, igual se compara contra un hash de
  relleno, para no revelar qué correos están registrados.
- **Verificación de correo**: la cuenta nace sin verificar y no puede iniciar sesión hasta escribir el
  código de 6 números que llega al correo. El mismo mecanismo sirve para recuperar la contraseña.
  - El código se guarda como HMAC-SHA256 con una clave derivada de `JWT_SECRET` (un hash simple no
    basta: solo hay un millón de códigos posibles). El HMAC incluye el usuario y el propósito, así que
    un código de verificación no sirve para cambiar la contraseña ni para otra cuenta.
  - Vence en 15 minutos, admite 5 intentos y pedir uno nuevo anula el anterior. Se emiten como máximo
    10 códigos por cuenta y propósito al día, lo que limita los intentos posibles a 50 diarios.
  - Entre dos solicitudes para el mismo correo hay que esperar 60 s (por correo escrito, exista o no
    la cuenta), y hay un tope por IP.
  - Registro, reenvío y recuperación responden siempre `202` con el mismo mensaje. El correo sale en
    segundo plano después de guardar, para que el tiempo de respuesta tampoco revele si la cuenta
    existe. Si alguien intenta registrar un correo ya verificado, solo se avisa a su dueño.
  - Registrar de nuevo un correo que nadie ha verificado reemplaza el nombre y la contraseña: así
    nadie puede "apartar" el correo de otra persona.
  - Las cuentas creadas antes de esta función quedaron verificadas en la migración V7.
  - Cambiar la contraseña con el código cierra todas las sesiones abiertas.
- **Consentimiento** (Ley 1581 de 2012): el registro exige `acceptPrivacyPolicy = true` y guarda la
  versión del aviso y la fecha de aceptación.
- **Eliminación de la cuenta**: borrado definitivo (no lógico) de alertas, evaluaciones, registros,
  vacas, sesiones, códigos y el usuario, en una sola transacción y después de confirmar la contraseña.
  Un token de acceso ya emitido sigue siendo válido hasta que vence (15 minutos), pero ya no hay datos
  que leer.
- Cambiar la contraseña y eliminar la cuenta usan el mismo límite de intentos que el login.
- **Límite de intentos** de login en memoria, por IP + correo y por IP; responde 429 con `Retry-After`.
  Vale para una sola instancia; detrás de un proxy hay que configurar
  `server.forward-headers-strategy` para tomar la IP real.
- **CORS** cerrado salvo los orígenes de `CORS_ALLOWED_ORIGINS`. La app Android no lo necesita.
- **Validación** con Bean Validation en todas las entradas, más restricciones `CHECK` en la base.
- **Consultas** solo con métodos de Spring Data y JPQL con parámetros; nada concatenado.
- **Aislamiento**: cada consulta filtra por el dueño. Una vaca ajena responde 404, igual que una
  inexistente. Las pruebas `CowIntegrationTest` y `SyncIntegrationTest` lo verifican.

## Sincronización

`POST /api/sync` recibe listas de `cows`, `dailyRecords`, `inferences` y `alerts` (máximo 500 de
cada una). Cada elemento trae su UUID (generado en el celular), `updatedAt` y `deleted`.

- **Upsert por UUID**: reenviar el mismo lote no duplica nada.
- **Gana la última modificación**: si el servidor tiene una versión más reciente, la conserva y
  el elemento igual se confirma.
- **Rechazos**: los elementos de otro usuario o que apuntan a una vaca ajena o inexistente vuelven en
  `rejected` con el motivo, y el resto del lote se guarda.
- La respuesta trae los ids confirmados por tipo; la app solo marca como sincronizado lo confirmado.

## Decisiones

- JWT con el *resource server* de Spring Security (Nimbus) en lugar de una librería aparte.
- Límite de intentos propio, en memoria, en lugar de Bucket4j: es suficiente para una instancia y
  no agrega dependencias.
- El checklist de síntomas se guarda como columnas booleanas (`udder_swelling`, `abnormal_milk`,
  `udder_pain`, `lethargy`), fáciles de consultar y validar.
