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

- El ganadero registra a diario, desde el celular, temperatura (°C), leche (L) y alimento (kg) de cada vaca.
- Un modelo **LSTM** analiza los últimos 14 días y estima la probabilidad de que aparezcan
  síntomas clínicos de mastitis en los próximos 1 a 5 días.
- El resultado se muestra como **semáforo**: verde (sano), amarillo (alerta temprana), rojo (alto riesgo),
  con una recomendación básica.
- Todo funciona **sin internet**: el modelo corre en el celular y los datos se guardan localmente.
  Cuando hay conexión, se sincronizan con el servidor.
- Más adelante: triaje visual de la ubre con una foto (CNN MobileNetV2), cuando haya imágenes reales.

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
                         │ /api/auth  /api/bovinos  /api/sync│
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
cp .env.example .env            # y definir JWT_SECRET
docker compose up -d
```

Documentación de la API en `http://localhost:8080/swagger-ui.html`.

**Aplicación (mobile/)**: requiere Flutter y un dispositivo o emulador Android (API 24+).

```bash
cd mobile
flutter pub get
flutter run
```

## Sobre los datos

Por ahora el modelo se entrena con un **dataset sintético** construido a partir de lo que reporta
la literatura sobre la fase subclínica de la mastitis. Las métricas que se obtienen con esos datos
sirven para comprobar que el pipeline funciona, **no para validar la hipótesis del proyecto**
(F1 ≥ 0,80). Para eso se necesitan registros reales de fincas; el mismo pipeline sirve para reentrenar.

## Contribuir

Ver [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md).
