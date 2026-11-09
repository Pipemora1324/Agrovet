# Diagramas

Hechos a partir del código de `develop` (migraciones Flyway V1 a V13, clases del backend y de la
app). La fuente es el archivo `.mmd` (Mermaid); el `.png` es su exportación.

| Archivo | Qué muestra |
|---|---|
| `01_arquitectura` | App Flutter sin conexión, backend Spring Boot, PostgreSQL, modelo TFLite en el celular, Gemini a través del backend y correo. |
| `02_modelo_datos` | Tablas y relaciones del esquema de PostgreSQL (resultado de V1 a V13). |
| `03a_componentes_mobile` | Capas presentation, domain y data de la app. |
| `03b_componentes_backend` | Controladores, servicios y repositorios del backend. |
| `04_sincronizacion` | Sincronización idempotente por UUID entre la app y `POST /api/sync`. |
| `05_registro_verificacion` | Registro de la cuenta con el código de verificación del correo. |
| `06_registro_semaforo` | Registro de hoy por preguntas y cálculo del semáforo combinado. |
| `07_despliegue` | Despliegue local actual y objetivo con Docker Compose y Caddy. |

## Volver a exportar

Con Docker (no hace falta instalar Node ni Chromium):

```bash
cd docs/diagrams
for f in *.mmd; do
  docker run --rm -u root -v "$PWD:/data" minlag/mermaid-cli:11.4.2 \
    -i "/data/$f" -o "/data/${f%.mmd}.png" -w 1600 -s 2 -b white
done
```
