# Matriz de trazabilidad

Cada requisito de [docs/REQUISITOS.md](../../REQUISITOS.md) con su historia de usuario, su issue,
los commits que lo implementaron, las pruebas automáticas que lo cubren y el resultado de la última
corrida. Los nombres de prueba se verificaron contra el código el 2026-11-10. Issue: #85.

- **Resultado:** «✅ CI v0.1.0» significa que pasó en las corridas de `main` (`97fe632`): backend
  [42722765485](https://github.com/Pipemora1324/Agrovet/actions/runs/42722765485), mobile
  [42722765899](https://github.com/Pipemora1324/Agrovet/actions/runs/42722765899) y ml
  [42722765481](https://github.com/Pipemora1324/Agrovet/actions/runs/42722765481).
- **Pull request:** hasta v0.1.0 las ramas se integraban con merge local `--no-ff`, sin PR. Por eso la
  columna de implementación enlaza commits. Desde el sprint 3 cada cambio entra por un PR.

## Requisitos funcionales

| Req. | HU | Issue | Implementación (commits) | Pruebas automáticas | Resultado |
|---|---|---|---|---|---|
| RF-01 Registro e inicio de sesión | HU-01 #45 | #1 | `e397c70`, `22003bb` | `AuthIntegrationTest.refreshRotatesAndReuseRevokesFamily`, `registerCreatesUnverifiedAccountAndEmailsCodeStoredOnlyAsHmac` | ✅ CI v0.1.0 |
| RF-02 Registro y edición de bovinos | HU-02 #46 | #2 | `2fb8ecd`, `bb951fe` | `CowIntegrationTest.crudFlow`, `listShowsOnlyOwnCows` | ✅ CI v0.1.0 |
| RF-03 Captura diaria con validación | HU-03 #47 | #3 | `4f39418`, `7312e35` | `SyncIntegrationTest.invalidValuesAreRejectedWithBadRequest`, `secondRecordForSameDayIsRejected`; `domain_test.dart` «acepta coma decimal…» | ✅ CI v0.1.0 |
| RF-04 Historial con gráficas | HU-05 #49 | #4 | `6fe7518`, `4d86f27` | `CowIntegrationTest.historyReturnsRecordsInRange` | ✅ CI v0.1.0 |
| RF-05 Inferencia LSTM sin conexión | HU-04 #48 | #5 | `585e69b`, `909e4f7` | `domain_test.dart` «con datos suficientes consulta el modelo…»; `test/model/test_vectors_test.dart`; `integration_test/test_vectors_on_device_test.dart` | ✅ CI v0.1.0 + emulador |
| RF-06 Semáforo con recomendación | HU-04 #48 | #6 | `313c82c`, `03caee6`, `b16fcd4` | `widgets_test.dart` «el resultado muestra el semáforo, la recomendación y el aviso fijo» | ✅ CI v0.1.0 |
| RF-07 Inferencias y alertas | HU-05 #49 | #7 | `793af49`, `341e814`, `32ca7cf` | `local_repository_test.dart` «marcar como atendida guarda la fecha…»; `SyncIntegrationTest.alertMarkedAsAttendedIsUpdatedAndShownInHistory` | ✅ CI v0.1.0 |
| RF-08 Sincronización idempotente | HU-06 #50 | #9 | `cc12e26`, `c2e0c13` | `SyncIntegrationTest.sameBatchTwiceCreatesNoDuplicates`, `olderVersionDoesNotOverwriteNewerOne`, `otherUserCannotOverwriteOrAttachToForeignData` | ✅ CI v0.1.0 |
| RF-08 (ampliación) Restauración en otro celular | HU-06 #50 | #63 | `4800bd2`, `095b3c8` | `restore_service_test.dart` (4 pruebas); `sync_cubit_test.dart` «traer los datos del servidor cuenta como última sincronización» | ✅ CI v0.1.0 + tableta |
| RF-09 Sincronización en segundo plano | HU-06 #50 | #10 | `060f498`, `24cecc9`, `b70fbb5` | `sync_service_test.dart` «sin red reintenta con espera exponencial…»; `sync_cubit_test.dart` «al volver la app al frente sube lo pendiente» | ✅ CI v0.1.0 + emulador |
| RF-10 Triaje visual con foto | HU-07 #51 | #11 | `9c5bb37`, `2e111f6`, `5bc828d` | `test_build_cnn_dataset.py`, `test_train_cnn.py`, `test_cnn_evaluation.py`, `test_udder_tflite_parity.py`; `udder_triage_card_test.dart` | ⚠️ **Parcial**: pruebas en verde, pero la CNN no está validada (sesgo de fondo) y sigue apagada |
| RF-11 Dataset sintético | HU-09 #53 | #12 | `5288e9b` | `test_generate_dataset.py::test_exactly_35_percent_of_cows_get_sick` | ✅ CI v0.1.0 |
| RF-12 Entrenamiento y evaluación del LSTM | HU-09 #53 | #13 | `880f4fb` | `test_train_lstm.py::test_split_has_no_cow_leakage_and_is_stratified` | ✅ CI v0.1.0 (métricas sintéticas) |
| RF-13 Exportación TFLite y vectores | HU-09 #53 | #15 | `70c7d89`, `3aeea8c` | `test_exported_model.py::test_model_uses_only_builtin_ops`, `test_tflite_reproduces_vectors` | ✅ CI v0.1.0 |
| RF-14 Verificación de correo y recuperación | HU-01 #45 | #28 | `47c063e`, `2be6a6a`, `2f3b468` | `AuthIntegrationTest.loginIsRefusedUntilEmailIsVerified`; `MailServerConfigTest`; `auth_test.dart` | ✅ CI v0.1.0 + emulador (prueba 1) |
| RF-15 Perfil, eliminación y consentimiento | HU-01 #45 | #29 | `9c92554`, `a0784d3` | `ProfileIntegrationTest` (8); `profile_test.dart` | ✅ CI v0.1.0 |
| RF-16 Registro flexible y puntaje por síntomas | HU-03 #47 | #30 | `ea07f71`, `af469e7`, `03caee6`, `131ad7a`, `7312e35`, `ea3a058` | `symptom_score_test.dart`; `cubits_test.dart`; `record_wizard_test.dart`; `SyncIntegrationTest.valueSourcesAreStoredShownAndValidated` | ✅ CI v0.1.0 + emulador (prueba 5); reglas provisionales (#92) |
| RF-17 Fotos de la ubre por vaca | HU-07 #51 | #31 | `07a949c`, `e65d0ff`, `2efce77`, `73e245c`, `8e130db` | `PhotoIntegrationTest` (6); `PhotoProcessorTest`; `photos_test.dart`; `photo_view_test.dart` | ✅ CI v0.1.0 + emulador (prueba 6) |
| RF-18 Asistente con IA | HU-08 #52 | #32 | `5c887dd`, `c28a272`, `8db3629`, `b5dee4d`, `4129389` | `AssistantIntegrationTest` (5); `GeminiClientTest` (5); `WaitTextTest`; `assistant_test.dart`; `formatters_test.dart` (`plainAssistantText`); `GeminiLiveTest` (a mano) | ✅ CI v0.1.0 + emulador (pruebas 8–11) + Gemini real 1/1 |

## Requisitos no funcionales

| Req. | HU | Issue | Implementación (commits) | Pruebas automáticas | Resultado |
|---|---|---|---|---|---|
| RNF-01 Funcionamiento sin conexión | HU-06 #50 | #16 | `9e17cd7`, `060f498`, `4129389` | `sync_service_test.dart`; `api_errors_test.dart` «sin respuesta no culpa solo a la señal…» | ✅ CI v0.1.0 + emulador en modo avión |
| RNF-02 Interfaz para trabajo de campo | — (épica #44) | #17 | `1c5f301`, `298fb2a`, `f18ee9e`, `c9ad614` | `theme_test.dart`; `responsive_test.dart`; `record_wizard_test.dart` (4 tamaños, letra al 130 %); `photo_view_test.dart` «…miden 56 dp»; `architecture_test.dart` | ⚠️ **Parcial**: falta celular de gama baja real (#17) |
| RNF-03 Seguridad de la API | HU-01 #45 | #18 | `82cb5f7`, `b2eab15`, `b3be9c2` | `AuthIntegrationTest.loginIsRateLimited`, `tokenSignedWithOtherKeyIsRejected`, `corsAllowsOnlyConfiguredOrigins`; `CowIntegrationTest.sqlInjectionInTagIsStoredAsPlainText`, `otherUserCannotReadUpdateDeleteOrSeeHistory`; `ProdProfileIntegrationTest`; `CorsPropertiesTest`; `LoginRateLimiterTest` | ✅ CI v0.1.0 |
| RNF-04 Paridad Python / Dart | HU-04 #48 | #19 | `1958a59`, `909e4f7` | `test/model/test_vectors_test.dart`; `integration_test/test_vectors_on_device_test.dart`; `test_preprocess.py` (22) | ✅ CI v0.1.0 + emulador |
| RNF-05 Compatibilidad Android | — (épica #41) | #21 | `f2ddee8`, `47ce603`, `43ba20b`, `95c6466`, `160de06` | Paso del CI `mobile` que falla si un APK pasa de 15 MB | ✅ CI v0.1.0: arm64 13,0 MB, armeabi-v7a 12,1 MB, x86_64 14,1 MB |
| RNF-06 Integración continua por módulo | — (épica #41) | #22 | `896f614`, `18d6e70`, `a625a36`, `47176bf`, `b3c98b4` | Workflows `ml`, `backend`, `mobile`, `dependency-review` | ⚠️ **Parcial**: falta exigir los checks con protección de ramas |
| RNF-07 Documentación de la API | — (épica #41) | #23 | `a8fe6de` | `AuthIntegrationTest.swaggerIsAvailable`; `ProdProfileIntegrationTest` (apagado en prod) | ✅ CI v0.1.0 |
| RNF-08 Datos protegidos en el celular | HU-06 #50 | #24 | `9e17cd7` | `encrypted_database_test.dart` «la biblioteca cargada es SQLCipher», «el archivo queda cifrado…» | ✅ CI v0.1.0 |

## Bugs de las pruebas en emulador → prueba que los cubre

| Bug | Requisito | Commit | Prueba |
|---|---|---|---|
| #66, #67 Última sincronización | RF-09 | `b70fbb5` | Verificado en el emulador (prueba 2 y 3) |
| #68 Textos del registro | RF-16 | `ea3a058` | `record_wizard_test.dart` |
| #69 «Foto del Hoy» | RF-17 | `ea3a058` | Verificado en el emulador (prueba 6) |
| #70 Markdown del asistente | RF-18 | `b5dee4d` | `formatters_test.dart` «quita el Markdown que devolvió Gemini en la prueba del emulador» |
| #71 Consejos sin internet ocultos | RF-18 | `b5dee4d` | Verificado en el emulador (prueba 9) |
| #72 Mensaje de backend caído | RNF-01 | `4129389` | `api_errors_test.dart` «sin respuesta no culpa solo a la señal y dice que los datos siguen guardados» |
| #73 «54 minuto(s)» | RF-18 | `4129389` | `WaitTextTest.usesSingularPluralAndRoundsMinutesUp`; `api_errors_test.dart` «un 429 conserva el detalle…» |
| #74, #75 Letra al 130 % y selectores | RNF-02 | `c9ad614` | `photo_view_test.dart` «con letra al 130 % en pantalla pequeña las opciones no parten palabras y miden 56 dp» |
