# Diagramas

Hechos a partir del código de `develop` (revisados el 2026-11-18) (migraciones Flyway V1 a V13, clases del backend y de la
app). La fuente es el archivo `.mmd` (Mermaid); el `.png` es su exportación.

| Archivo | Qué muestra |
|---|---|
| `01_arquitectura` | App Flutter sin conexión, backend Spring Boot, PostgreSQL, modelo LSTM TFLite en el celular, modelos experimentales de ubre (`UDDER_TRIAGE`) y de leche (`DEMO_MODE`), pantalla «Acerca del modelo», conexión por `DB_URL` o `DATABASE_URL`, Gemini a través del backend y correo. |
| `02_modelo_datos` | Tablas y relaciones del esquema de PostgreSQL (resultado de V1 a V13). |
| `03a_componentes_mobile` | Capas presentation, domain y data de la app, con la demostración (`DemoSeed`), la restauración, el estado de conexión, la leche experimental, el triaje de la ubre y «Acerca del modelo». |
| `03b_componentes_backend` | Controladores, servicios, repositorios y configuración del backend (incluye `DatabaseUrlEnvironmentPostProcessor`). |
| `04_sincronizacion` | Sincronización idempotente por UUID entre la app y `POST /api/sync`. |
| `05_registro_verificacion` | Registro de la cuenta con el código de verificación del correo. |
| `06_registro_semaforo` | Registro de hoy por preguntas y cálculo del semáforo combinado. |
| `07_despliegue` | Despliegue local actual, demostración en Render (plan gratuito) con su APK, y objetivo en una VPS con Docker Compose y Caddy (aún no desplegado). |

## Volver a exportar

Con Docker (no hace falta instalar Node ni Chromium):

```bash
cd docs/diagrams
for f in *.mmd; do
  docker run --rm -u root -v "$PWD:/data" minlag/mermaid-cli:11.4.2 \
    -i "/data/$f" -o "/data/${f%.mmd}.png" -w 1600 -s 2 -b white
done
```
