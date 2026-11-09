# AgroVet

Sistema de alerta temprana de mastitis bovina para pequeños ganaderos de Nariño, Colombia.

Trabajo de grado — Ingeniería de Software, Universidad Cooperativa de Colombia, sede Pasto.
Autor: Juan Felipe Mora.

> **AgroVet apoya la decisión del veterinario, no la reemplaza.** Ante una alerta, el
> ganadero debe consultar a un profesional. La aplicación lo indica en pantalla.

## El problema

La mastitis es la enfermedad más costosa de los hatos lecheros: baja la producción, obliga
a descartar leche y, si se detecta tarde, deja daño permanente en la ubre. En las fincas
pequeñas de Nariño casi siempre se identifica cuando ya hay síntomas clínicos. Antes de eso
suele haber señales sutiles: sube un poco la temperatura, baja la leche y la vaca come menos.

## Qué hace

- **Cuenta segura**: registro con verificación del correo (código de 6 números), recuperación de
  contraseña, perfil editable, eliminación de la cuenta con todos sus datos y aviso de privacidad
  (Ley 1581 de 2012).
- **Registro diario flexible**: dos preguntas simples (¿comió normal?, ¿dio menos leche?), cinco signos
  de la ubre y, si se toman, temperatura (°C), leche (L) y alimento (kg).
- **Semáforo**: verde (sin señales), amarillo (alerta temprana) o rojo (alto riesgo). Es el más grave
  entre un **puntaje por síntomas** (reglas provisionales, a validar con un veterinario) y un modelo
  **LSTM** que analiza los últimos 14 días; la pantalla dice cuál lo indicó.
- **Fotos** de la ubre por vaca, sin ubicación, con permiso expreso opcional para investigación.
- **Asistente con IA** por vaca: orienta, no diagnostica; sin internet muestra consejos fijos.
- Todo lo esencial funciona **sin internet**: el modelo corre en el celular y los datos se guardan
  cifrados. Cuando hay conexión, se sincronizan con el servidor.
- Pendiente: triaje visual con una CNN (MobileNetV2), cuando haya fotos reales confirmadas.

## Arquitectura

```
 ┌──────────────── Celular Android (offline) ────────────────┐
 │  Flutter + BLoC                                           │
 │  Registro diario ──► SQLite (Drift) ──► Ventana 14 días   │
 │                                         │                 │
 │                          Preprocesamiento ─► LSTM (TFLite)│
 │                                         │                 │
 │                                      Semáforo             │
 │  Cola de cambios ──(workmanager, con conexión)──┐         │
 └─────────────────────────────────────────────────┼─────────┘
                                                   ▼ HTTPS + JWT
                         ┌──────────── Servidor ────────────┐
                         │ Spring Boot 3 ─► PostgreSQL 15   │
                         │ /api/auth  /api/cows  /api/sync  │
                         └──────────────────────────────────┘

 ml/ (Python): dataset ─► entrenamiento LSTM ─► .tflite + model_config.json ─► app
```

## Estructura del repositorio

| Carpeta    | Contenido                                                                 |
|------------|---------------------------------------------------------------------------|
| `ml/`      | Generación de datos, entrenamiento del LSTM y exportación a TFLite (Python, TensorFlow). |
| `backend/` | API REST de sincronización y gestión (Java 21, Spring Boot 3, PostgreSQL). |
| `mobile/`  | Aplicación Android (Flutter).                                             |
| `docs/`    | Documentación del proyecto y guía de contribución.                        |
| `scripts/` | Utilidades del repositorio (etiquetas e issues en GitHub).                |

Cada módulo tiene su propio README con instrucciones detalladas.

## Cómo ejecutar

**Modelo (ml/)**

```bash
cd ml
python -m venv .venv
.venv\Scripts\activate          # Windows  (Linux/Mac: source .venv/bin/activate)
pip install -r requirements.txt
python src/generate_dataset.py
python src/train_lstm.py
python src/export_tflite.py
python src/export_test_vectors.py
```

**Servidor (backend/)**: requiere Docker.

```bash
cd backend
cp .env.example .env            # y definir JWT_SECRET (y GEMINI_API_KEY para el asistente)
docker compose up -d
```

Documentación de la API en `http://localhost:8080/swagger-ui.html`; los correos de prueba (códigos de
verificación) llegan a Mailpit en `http://localhost:8025`.

**Correo: Mailpit o Gmail.** El backend elige solo, según `backend/.env`:

- *Mailpit (desarrollo)*: deje `MAIL_USERNAME` y `MAIL_PASSWORD` vacíos. Ningún correo sale del
  equipo; todos se ven en `http://localhost:8025`.
- *Gmail (correos de verdad)*: active la verificación en dos pasos de la cuenta, cree una
  *contraseña de aplicación* (Cuenta de Google → Seguridad → Contraseñas de aplicaciones) y póngala
  en `.env`:

  ```
  MAIL_HOST=smtp.gmail.com
  MAIL_PORT=587
  MAIL_USERNAME=su.cuenta@gmail.com
  MAIL_PASSWORD=abcdefghijklmnop     # los 16 caracteres, sin espacios
  MAIL_FROM=AgroVet <su.cuenta@gmail.com>
  ```

  El envío usa STARTTLS obligatorio. Para volver a Mailpit, vacíe `MAIL_USERNAME` y `MAIL_PASSWORD`.
  Después de cambiar `.env`: `docker compose up -d backend`. El log de arranque dice qué modo quedó
  (`Correo: Mailpit ...` o `Correo: SMTP smtp.gmail.com:587 con STARTTLS`).

`.env` está en `.gitignore`: las claves (Gmail, `GEMINI_API_KEY`, `JWT_SECRET`) nunca se suben.

**Servidor propio.** `docs/DEPLOY.md` explica cómo levantar el backend en una VPS con
`docker-compose.prod.yml` (perfil `prod`, HTTPS con Caddy y `/actuator/health` para el chequeo).

**Aplicación (mobile/)**: requiere Flutter y un dispositivo o emulador Android (API 24+).

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080   # emulador (el equipo es 10.0.2.2)
```

En un celular o tableta por USB, con el backend corriendo en el equipo:

```bash
adb reverse tcp:8080 tcp:8080
adb reverse tcp:8025 tcp:8025   # para abrir Mailpit desde el celular
flutter run -d <dispositivo> --dart-define=API_BASE_URL=http://localhost:8080
```

## Sobre los datos

Por ahora el modelo se entrena con un **dataset sintético** construido a partir de lo que reporta
la literatura sobre la fase subclínica de la mastitis. Las métricas que se obtienen con esos datos
sirven para comprobar que el pipeline funciona, **no para validar la hipótesis del proyecto**
(F1 ≥ 0,80). Para eso se necesitan registros reales de fincas; el mismo pipeline sirve para reentrenar.

## Contribuir

Ver [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md).
