# Revisión de los 9 hallazgos antiguos de SonarCloud en `main`

Hallazgos abiertos en `main` el 2026-11-17 (8 de octubre a noviembre, anteriores a v0.2.0): 4 errores
(*bugs*) y 5 vulnerabilidades. No hay *security hotspots* pendientes. Se revisó cada uno contra el
código.

**Ninguno se marcó en SonarCloud.** Los 5 falsos positivos se proponen como "revisados", con la
justificación de abajo, y esperan la aprobación del responsable del proyecto. Los 4 reales se
corrigen en este PR.

## Corregidos en el código (4)

| Clave | Regla | Dónde | Qué pasaba | Corrección y prueba |
|---|---|---|---|---|
| `AaHmJMkHTw0Zwb2UYxVd` | java:S2077 (SQL armado con texto) | `user/AccountDeletionService.java:49` | No era inyectable: el nombre de la tabla salía de una constante del código y el id iba como parámetro. Pero el SQL se armaba concatenando texto, y un cambio futuro podía meter un valor externo. | Las 4 sentencias quedan escritas completas en una lista constante, sin concatenar. Lo cubre `ProfileIntegrationTest.deletingTheAccountRemovesAllItsDataAndOnlyItsData`: borra todo lo de la cuenta y nada de las otras. |
| `AaHmJMj1Tw0Zwb2UYxVS` | java:S2184 (resta `int` que podría desbordar) | `cow/CowService.java:86` | `DEFAULT_HISTORY_DAYS - 1` es una constante (60 − 1) y no desborda; en la práctica no fallaba. | `- 1L`. Prueba nueva `CowIntegrationTest.historyWithoutDatesCoversTheLastSixtyDays`: sin fechas, el historial va de hoy a 59 días atrás, el día 60 queda fuera. |
| `AaHmJMjoTw0Zwb2UYxVM` | kotlin:S7204 (ofuscación en release) | `mobile/android/app/build.gradle.kts:59` | R8 ya corría: el plugin de Flutter lo activa en release (`FlutterPlugin.kt`) y el build dejaba `mapping.txt`. Sonar no lo ve porque solo lee este archivo, y la ofuscación dependía de un valor por defecto externo. | `isMinifyEnabled = true` y `isShrinkResources = true` explícitos. Comprobado: el `classes.dex` del APK release arm64 es idéntico byte a byte antes y después (SHA-256 `eb84d430…b22e1c`, APK de 13 662 203 bytes). |
| `AaHmJMlFTw0Zwb2UYxWG` | python:S5863 (misma expresión a ambos lados) | `ml/tests/test_train_lstm.py:21` | La prueba quería comprobar que la partición es reproducible, pero `split_cows(df) == split_cows(df)` parece comparar algo consigo mismo. | Dos llamadas guardadas en variables distintas y comparadas. |

## Falsos positivos: propuesta de marca "revisado" (5, sin aplicar)

| Clave | Regla | Dónde | Marca propuesta | Justificación |
|---|---|---|---|---|
| `AaHmJMkETw0Zwb2UYxVa` | java:S4502 (CSRF apagado) | `config/SecurityConfig.java:42` | Seguro / falso positivo | La API no usa sesión ni cookies (`SessionCreationPolicy.STATELESS`). El token JWT viaja en la cabecera `Authorization`, que un sitio ajeno no puede poner en una petición del navegador. Sin cookies de autenticación no hay ataque CSRF posible. No hay ningún uso de cookies en `backend/src/main/java`. |
| `AaHmJMjwTw0Zwb2UYxVP` | java:S2068 (contraseña escrita en el código) | `auth/AuthService.java:45` | Falso positivo | `WRONG_PASSWORD` es el texto que ve la persona cuando se equivoca ("La contraseña no es correcta."), no una credencial. La regla se activa solo por el nombre de la constante. |
| `AaHmJMkdTw0Zwb2UYxVz` | plsql:DeleteOrUpdateWithoutWhereCheck | `db/migration/V7__email_verification.sql:5` | Aceptado (intencional) | `UPDATE users SET email_verified = TRUE` sin `WHERE` es a propósito: la columna nació con V7 y las cuentas creadas antes ya estaban en uso, así que todas se dan por verificadas, como dice el comentario de la línea 4. Además, una migración de Flyway ya aplicada no se puede editar: cambiarla rompe la validación de checksum en toda base existente. |
| `AaHmJMjmTw0Zwb2UYxVK` | xml:S5332 (tráfico sin cifrar implícito) | `mobile/android/app/src/debug/AndroidManifest.xml:9` | Falso positivo | Es el manifiesto de **debug**. Al compilar se fusiona con `src/main/AndroidManifest.xml`, que declara `android:usesCleartextTraffic="false"`. Además, la app exige Android 7.0 (minSdk 24), y desde esa versión manda `network_security_config.xml`. En debug, ese archivo solo permite HTTP hacia `10.0.2.2`, `localhost` y `127.0.0.1`. El release no tiene este manifiesto. |
| `AaHmJMjmTw0Zwb2UYxVL` | xml:S6358 (copia de seguridad de datos) | `mobile/android/app/src/debug/AndroidManifest.xml:9` | Falso positivo | Mismo caso: el manifiesto principal, que se fusiona con este, declara `android:allowBackup="false"`, `android:fullBackupContent="false"` y `dataExtractionRules`. Los datos (base SQLCipher y almacenamiento seguro) no salen en copias de seguridad, ni en debug ni en release. |

Para aplicarlas: en SonarCloud, *Issues*, filtrar la rama `main`, abrir cada clave, *Change status*
→ *False positive* (o *Accept* para la migración V7) y pegar la justificación como comentario.
