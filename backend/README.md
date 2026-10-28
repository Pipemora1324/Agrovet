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

Para pasar a un servidor propio (VPS) solo cambian estas variables: el mismo código y las mismas
migraciones sirven para cualquier PostgreSQL 15.

## Endpoints

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/api/auth/register` | Crea la cuenta y devuelve tokens. |
| POST | `/api/auth/login` | Inicia sesión (con límite de intentos). |
| POST | `/api/auth/refresh` | Renueva la sesión; el refresh token usado deja de servir. |
| POST | `/api/auth/logout` | Revoca la sesión. |
| GET | `/api/auth/me` | Usuario autenticado. |
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
