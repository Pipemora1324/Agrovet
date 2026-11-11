# Evidencias de pruebas

Resultados reales de las pruebas de AgroVet en la versión **v0.1.0** (`main`, commit `97fe632`,
2026-11-09). Cada sección dice qué se probó, dónde está la corrida y cómo repetirla.

| Evidencia | Documento | Issue |
|---|---|---|
| Corridas automáticas del CI (backend, mobile, ml) | este archivo | #80, #81, #82 |
| Matriz requisito → issue → commit → prueba → resultado | [trazabilidad.md](trazabilidad.md) | #85 |
| 13 pruebas reales en emulador y los 10 problemas corregidos | [emulador.md](emulador.md) | #83 |
| Calidad de los datos públicos, CNN y límites del LSTM | [calidad_datos.md](calidad_datos.md) | #84 |

## Corridas de GitHub Actions en `main` (v0.1.0)

Las cinco corridas del commit `97fe632` terminaron en verde:

| Workflow | Resultado | Pruebas | Corrida |
|---|---|---|---|
| `backend` | ✅ éxito | **104** (103 pasan, 1 omitida: `GeminiLiveTest`, que solo corre con `GEMINI_LIVE_TEST=true`) | [42722765485](https://github.com/Pipemora1324/Agrovet/actions/runs/42722765485) |
| `mobile` | ✅ éxito | **188** pasan, `flutter analyze` limpio, APK por arquitectura ≤ 15 MB | [42722765899](https://github.com/Pipemora1324/Agrovet/actions/runs/42722765899) |
| `ml` | ✅ éxito | **80** pasan, `flake8` limpio | [42722765481](https://github.com/Pipemora1324/Agrovet/actions/runs/42722765481) |
| `dependency-review` | ✅ éxito | revisión de dependencias nuevas | [42722766002](https://github.com/Pipemora1324/Agrovet/actions/runs/42722766002) |
| Dependency Graph | ✅ éxito | envío automático del grafo | [42722768579](https://github.com/Pipemora1324/Agrovet/actions/runs/42722768579) |

## Backend

`./mvnw verify` con JUnit 5 y Testcontainers (PostgreSQL 15 real en Docker). Pruebas por clase,
tomadas del log de la corrida:

| Clase | Pruebas | Qué cubre |
|---|---|---|
| `auth.AuthIntegrationTest` | 23 | registro con verificación, login, refresh con rotación y reuso, rate limit, CORS, token con otra clave, Swagger |
| `sync.SyncIntegrationTest` | 15 | lotes idempotentes, última escritura gana, rangos, un registro por día, alertas atendidas, origen medido/estimado, datos ajenos |
| `auth.AuthServiceTest` | 9 | reglas del servicio de autenticación |
| `cow.CowIntegrationTest` | 9 | CRUD, historial por rango, aislamiento por usuario, inyección SQL guardada como texto |
| `auth.ProfileIntegrationTest` | 8 | perfil, contraseña, consentimiento, eliminación de la cuenta con todos sus datos |
| `photo.PhotoIntegrationTest` | 6 | tipo real del archivo, tamaño, EXIF con GPS eliminado, 404 para otro usuario |
| `auth.LoginRateLimiterTest` | 5 | límite de intentos de login |
| `assistant.GeminiClientTest` | 5 | formato de la petición, modelo retirado, saturación del proveedor |
| `assistant.AssistantIntegrationTest` | 5 | contexto sin datos personales, foto sin GPS, límite por usuario, 503 |
| `mail.MailServerConfigTest` | 4 | Gmail con STARTTLS obligatorio o Mailpit |
| `ProdProfileIntegrationTest` | 4 | perfil `prod`: Swagger apagado, CORS cerrado |
| `auth.code.CodeRequestLimiterTest` | 3 | espera de 60 s y tope diario de códigos |
| `FlywayMigrationIntegrationTest` | 2 | se aplican todas las migraciones (V1..V13) y existen las tablas esperadas |
| `config.CorsPropertiesTest` | 2 | orígenes permitidos por variable de entorno |
| `photo.PhotoProcessorTest` | 2 | reducción y limpieza de la foto |
| `auth.WaitTextTest` | 1 | texto de espera en singular o plural |
| `assistant.GeminiLiveTest` | 1 (omitida en CI) | llamada real a Gemini; corrida a mano el 2026-11-09: 1/1 en 13,9 s |
| **Total** | **104** | |

Reproducir (requiere Docker y JDK 21):

```bash
cd backend
./mvnw verify
```

## Mobile

`flutter test` corre 188 pruebas en 27 archivos:

- `test/core/`: configuración, formato de textos (incluida la limpieza del Markdown del asistente) y tema (textos ≥ 16 sp, controles de 56 dp).
- `test/data/`: base cifrada real con SQLCipher, repositorio local, migraciones, fotos, restauración desde el servidor, sincronización con reintentos y mensajes de error de la API.
- `test/domain/`: preprocesamiento, semáforo, recomendaciones y puntaje por síntomas.
- `test/model/`: vectores de prueba del TFLite (paridad con Python, tolerancia 1e-4) y modelo de la ubre.
- `test/presentation/`: pantallas y cubits (ingreso, perfil, registro por preguntas, ficha, fotos, asistente, sincronización) y diseño en 4 tamaños con letra al 130 %.
- `test/architecture_test.dart`: prohíbe colores y tamaños de letra fuera del tema.

Además, en un emulador Android (`integration_test/`):

- `test_vectors_on_device_test.dart`: el TFLite reproduce los vectores en el dispositivo.
- `app_flow_test.dart`: recorrido completo de la app, 4/4.

El CI arma un APK por arquitectura y falla si alguno pasa de 15 MB. En v0.1.0: arm64-v8a 13,0 MB,
armeabi-v7a 12,1 MB y x86_64 14,1 MB.

Reproducir:

```bash
cd mobile
flutter analyze
flutter test
# en un emulador, con el backend y Mailpit del docker-compose arriba:
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/app_flow_test.dart \
  -d <dispositivo> --keep-app-running --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

## ml

`pytest` con 80 pruebas:

| Archivo | Pruebas | Qué cubre |
|---|---|---|
| `test_preprocess.py` | 22 | ventanas de 14 días y normalización (la misma que replica la app) |
| `test_generate_dataset.py` | 12 | dataset sintético: semilla, 35 % de vacas enfermas, fase subclínica |
| `test_udder_public_data.py` | 10 | recorte y agrupación por vaca del dataset público de ubres |
| `test_cnn_evaluation.py` | 8 | folds sin fuga entre grupos, intervalos de Wilson y bootstrap |
| `test_exported_model.py` | 6 | TFLite solo con operaciones integradas y reproducción de los vectores |
| `test_train_lstm.py` | 5 | partición por vaca sin fuga y estratificada, umbral por F1 |
| `test_build_cnn_dataset.py` | 5 | solo fotos con consentimiento y confirmación veterinaria |
| `test_train_cnn.py` | 4 | entrenamiento de humo de la CNN |
| `test_udder_tflite_parity.py` | 4 | CNN en TFLite frente a Keras |
| `test_milk_public_poc.py` | 4 | prueba de concepto de pocillos de leche |
| **Total** | **80** | |

Reproducir:

```bash
cd ml
python -m venv .venv && .venv/Scripts/activate   # en Linux: source .venv/bin/activate
pip install -r requirements.txt
pytest -q
flake8
```

> Las métricas del LSTM salen de un **dataset sintético** (test: F1 0,492, AUC 0,891). Sirven para
> comprobar el pipeline, pero **no validan** la hipótesis del proyecto (F1 ≥ 0,80).
