# Requisitos y su estado

Estado real de cada requisito a la fecha de este documento, en la rama `develop`. Cada requisito
tiene su issue en GitHub, donde está la evidencia completa. Los estados salen de esos issues:

- **Cumplido**: el issue está cerrado con evidencia (pruebas automáticas y, cuando aplica, una
  prueba en el emulador o contra Docker).
- **Parcial**: el issue sigue abierto; la columna "Falta" dice qué.
- **Pendiente**: no se ha empezado. Hoy no hay ninguno en este estado.

Las pruebas citadas existen en el código actual. Resultado de la última corrida: `./mvnw verify`
99 pruebas OK, `flutter test` 159 OK, `pytest` 54 OK y el recorrido completo en el emulador
(`integration_test/app_flow_test.dart`) 4/4.

> Los resultados del modelo LSTM salen de un **dataset sintético**. Sus métricas (F1 0,492 en test)
> sirven para comprobar el pipeline, pero **no validan** la hipótesis del proyecto (F1 ≥ 0,80).

## Requisitos funcionales

| Id | Requisito | Estado | Respaldo (commit / prueba) | Falta o nota |
|---|---|---|---|---|
| RF-01 | Registro e inicio de sesión (#1) | Cumplido | `e397c70`, `22003bb` · `AuthIntegrationTest.refreshRotatesAndReuseRevokesFamily`, `registerCreatesUnverifiedAccountAndEmailsCodeStoredOnlyAsHmac` | Desde RF-14 el registro exige verificar el correo. |
| RF-02 | Registro y edición de bovinos (#2) | Cumplido | `2fb8ecd`, `bb951fe` · `CowIntegrationTest.crudFlow`, `listShowsOnlyOwnCows` | |
| RF-03 | Captura diaria con validación de rangos (#3) | Cumplido | `4f39418`, `7312e35` · `SyncIntegrationTest.invalidValuesAreRejectedWithBadRequest`, `secondRecordForSameDayIsRejected`; `domain_test.dart` ("acepta coma decimal…") | Hoy la captura es el registro por preguntas (RF-16); los rangos se validan en las medidas exactas. |
| RF-04 | Historial por bovino con gráficas (#4) | Cumplido | `6fe7518`, `4d86f27` · `CowIntegrationTest.historyReturnsRecordsInRange` | El historial también marca cada valor como medido o estimado. |
| RF-05 | Inferencia LSTM sin conexión (#5) | Cumplido | `585e69b`, `909e4f7` · `domain_test.dart` ("con datos suficientes consulta el modelo…"), `test/model/test_vectors_test.dart`, `integration_test/test_vectors_on_device_test.dart` | Modelo entrenado con datos sintéticos. |
| RF-06 | Semáforo de riesgo con recomendación (#6) | Cumplido | `313c82c`, `03caee6` · `widgets_test.dart` ("el resultado muestra el semáforo, la recomendación y el aviso fijo") | |
| RF-07 | Registro de inferencias y alertas (#7) | Cumplido | `793af49`, `341e814`, `32ca7cf` · `local_repository_test.dart` ("marcar como atendida guarda la fecha…"), `SyncIntegrationTest.alertMarkedAsAttendedIsUpdatedAndShownInHistory` | |
| RF-08 | Sincronización por lotes idempotente (#9) | Cumplido | `cc12e26`, `c2e0c13` · `SyncIntegrationTest.sameBatchTwiceCreatesNoDuplicates`, `olderVersionDoesNotOverwriteNewerOne`, `otherUserCannotOverwriteOrAttachToForeignData` | |
| RF-09 | Sincronización en segundo plano (#10) | Cumplido | `060f498`, `24cecc9` · `sync_service_test.dart` ("sin red reintenta con espera exponencial…"), `sync_cubit_test.dart` ("al volver la app al frente sube lo pendiente") | En el emulador, Android agrupó la tarea de WorkManager; se forzó con `cmd jobscheduler` y terminó en SUCCESS. |
| RF-10 | Triaje visual de la ubre con foto (#11) | **Parcial** | `07a949c`, `e65d0ff`, `2e111f6` · `PhotoIntegrationTest`, `ml/tests/test_build_cnn_dataset.py`, `ml/tests/test_train_cnn.py` (prueba de humo) | CNN entrenada con un dataset público (5×5 por vaca: AUC 0,87, pero en un mismo establo la sensibilidad baja a 0,55–0,58 y un modelo que solo ve el fondo llega a AUC 0,75: sesgo). Apagada en la app (`UDDER_TRIAGE`). Faltan fotos reales confirmadas por un veterinario (al menos 50 por clase) para validarla. |
| RF-11 | Dataset sintético de entrenamiento (#12) | Cumplido | `5288e9b` · `test_generate_dataset.py::test_exactly_35_percent_of_cows_get_sick` | Sintético: no reemplaza datos reales de finca. |
| RF-12 | Entrenamiento y evaluación del LSTM (#13) | Cumplido | `880f4fb` · `test_train_lstm.py::test_split_has_no_cow_leakage_and_is_stratified` | Test sintético: F1 0,492, AUC 0,891. No valida la hipótesis. |
| RF-13 | Exportación a TFLite y vectores de prueba (#15) | Cumplido | `70c7d89`, `3aeea8c` · `test_exported_model.py::test_model_uses_only_builtin_ops`, `test_tflite_reproduces_vectors` | |
| RF-14 | Verificación del correo y recuperación de contraseña (#28) | Cumplido | `47c063e`, `2be6a6a`, `2f3b468` · `AuthIntegrationTest.loginIsRefusedUntilEmailIsVerified`, `MailServerConfigTest`, `auth_test.dart` | Probado con Mailpit y con un envío real por Gmail (respuesta 202 sin errores en el log). |
| RF-15 | Perfil, eliminación de cuenta y consentimiento (#29) | Cumplido | `9c92554`, `a0784d3` · `ProfileIntegrationTest`, `profile_test.dart` | El autor debe confirmar los datos del responsable en el aviso de privacidad. |
| RF-16 | Registro diario flexible y puntaje por síntomas (#30) | Cumplido | `ea07f71`, `af469e7`, `03caee6`, `131ad7a`, `7312e35` · `symptom_score_test.dart`, `cubits_test.dart`, `record_wizard_test.dart`, `SyncIntegrationTest.valueSourcesAreStoredShownAndValidated` | Reglas y equivalencias provisionales, pendientes de validar con un veterinario (`docs/symptom_score.md`). |
| RF-17 | Fotos de la ubre por vaca (#31) | Cumplido | `07a949c`, `e65d0ff`, `2efce77`, `73e245c` · `PhotoIntegrationTest`, `photos_test.dart` | La cámara real no se ha probado a mano en un dispositivo. |
| RF-18 | Asistente con IA por vaca (#32) | Cumplido | `5c887dd`, `c28a272` · `AssistantIntegrationTest`, `GeminiClientTest`, `assistant_test.dart` | Probado con un proveedor simulado; las respuestas reales de Gemini aún no se han probado. |

## Requisitos no funcionales

| Id | Requisito | Estado | Respaldo (commit / prueba) | Falta o nota |
|---|---|---|---|---|
| RNF-01 | Funcionamiento sin conexión (#16) | Cumplido | `9e17cd7`, `060f498` · `sync_service_test.dart`; recorrido en el emulador en modo avión (evidencia en #16) | |
| RNF-02 | Interfaz apta para trabajo de campo (#17) | **Parcial** | `1c5f301`, `298fb2a`, `f18ee9e` · `theme_test.dart` (textos ≥ 16 sp, controles de 56 dp), `responsive_test.dart` y `record_wizard_test.dart` (4 tamaños con letra al 130 %) | Falta probar el APK de release en un celular de gama baja real (fluidez, arranque, lectura a pleno sol) y la vista de tableta en una tableta real. |
| RNF-03 | Seguridad de la API (#18) | Cumplido | `82cb5f7`, `b2eab15`, `b3be9c2` · `AuthIntegrationTest.loginIsRateLimited`, `tokenSignedWithOtherKeyIsRejected`, `corsAllowsOnlyConfiguredOrigins`; `CowIntegrationTest.sqlInjectionInTagIsStoredAsPlainText`, `otherUserCannotReadUpdateDeleteOrSeeHistory`; `ProdProfileIntegrationTest`, `CorsPropertiesTest` | |
| RNF-04 | Paridad del preprocesamiento Python / Dart (#19) | Cumplido | `1958a59`, `909e4f7` · `test/model/test_vectors_test.dart`, `integration_test/test_vectors_on_device_test.dart` | |
| RNF-05 | Compatibilidad Android (#21) | Cumplido | `f2ddee8`, `47ce603`, `43ba20b`, `95c6466`, `160de06` · el CI `mobile` falla si un APK pasa de 15 MB | minSdk 24; APK arm64 de 12,5 MB. |
| RNF-06 | Integración continua por módulo (#22) | **Parcial** | `896f614`, `18d6e70`, `a625a36`, `47176bf`, `b3c98b4` · workflows `ml`, `backend`, `mobile` y `dependency-review` en verde | Falta activar en GitHub la protección de `develop` y `main` con esos checks como obligatorios (hoy no los exige nada). |
| RNF-07 | Documentación de la API (#23) | Cumplido | `a8fe6de` · `AuthIntegrationTest.swaggerIsAvailable` | Swagger está disponible en desarrollo y apagado en el perfil `prod` (`ProdProfileIntegrationTest`). |
| RNF-08 | Protección de los datos en el celular (#24) | Cumplido | `9e17cd7` · `encrypted_database_test.dart` ("la biblioteca cargada es SQLCipher", "el archivo queda cifrado…") | |

## Avances sin issue propio

Trabajo hecho después de cerrar los issues y que todavía no tiene un requisito propio:

- Registro de hoy como asistente por preguntas, con el origen de cada valor (medido o estimado):
  `131ad7a`, `ed236f5`, `7312e35`, `31c097a`; amplía RF-16.
- Rediseño visual y pruebas de tamaños de pantalla: `298fb2a`, `1469989`, `f18ee9e`, `83b2b53`;
  apoya RNF-02.
- Preparación para el despliegue (perfil `prod`, HTTPS obligatorio en release, Compose con Caddy y
  `docs/DEPLOY.md`): `33f9fd7`, `b3be9c2`, `6f44661`. El backend **no está desplegado** todavía.
