# Ficha de datos verificados para la tesis

Datos del proyecto comprobados el **2026-11-18** contra el repositorio, GitHub, el CI, SonarCloud y el
servidor de demostración. Cada dato lleva su fuente: un archivo, un comando o una ejecución del CI. Lo
que no se pudo verificar se dice así.

Esta ficha no lleva secretos: ni claves, ni la dirección de la base de datos, ni contraseñas, ni la
dirección real del servidor de demostración.

## 1. Estado de `develop` y `main`

| Dato | Valor | Fuente |
|---|---|---|
| Último commit de `develop` | `54ce15d` (2026-11-17), integración del PR #126 | `git log -1 origin/develop` |
| Último commit de `main` | `dcad510` (2026-11-16), integración de `develop` para la v0.2.0 | `git log -1 origin/main` |
| Etiquetas | `v0.1.0` → `97fe632` (2026-11-09); `v0.2.0` → `dcad510` (2026-11-16) | `git tag -l` |
| Versión del código | `0.2.0+2` (`mobile/pubspec.yaml`); la v0.2.0 está en `main` | archivo |

**PR y números #104 a #126** (`gh pr list --state all`, `gh api issues/<n>`, `git merge-base --is-ancestor`):

| # | Tipo y estado | Título | Dónde quedó |
|---|---|---|---|
| 104 | PR integrado (16-11) | Evaluación del asistente con la API real y mejoras del prompt | `main` y `develop` |
| 105 | PR integrado (16-11) | Compilación de demostración para usar la app sin servidor | `main` y `develop` |
| 106–111 | Issues cerrados (16-11) | Calidad del CI, evaluación de leche, robustez del LSTM, evaluación del asistente, compilación de demostración, entrega v0.2.0 | — |
| 112 | PR integrado (16-11) | Corrige las vulnerabilidades del CI que hacían fallar el Quality Gate | `main` y `develop` |
| 113 | PR integrado (16-11) | Lee los resultados de mutmut de la entrada estándar | `main` y `develop` |
| 114 | PR integrado (17-11) | Pantalla experimental de leche, «Acerca del modelo» y mejoras del APK de demostración | solo `develop` |
| 115 | PR integrado (17-11) | Plan de despliegue de demostración en Render | solo `develop` |
| 116 | PR integrado (17-11) | Corrige los hallazgos antiguos de SonarCloud y propone revisar los falsos positivos | solo `develop` |
| 117 | PR integrado (17-11) | Sube la versión a 0.2.0 | solo `develop` |
| 118 | PR integrado (17-11) | Despliegue de demostración en Render: Blueprint, datos de demostración y APK con la URL | solo `develop` |
| 119–123 | PR abiertos, de Dependabot | Maven 3.10.1, fl_chart 1.3.1, drift_dev 2.35.3, sqlite3 3.9.1, drift 2.35.4 | sin integrar |
| 124 | PR integrado (17-11) | Quita `rootDir` del Blueprint de Render | solo `develop` |
| 125 | PR integrado (17-11) | Ignora la carpeta local `apk` | solo `develop` |
| 126 | PR integrado (17-11) | Mejora el uso sin conexión con una cuenta real (ingreso, asistente y guardado) | solo `develop` |

También siguen abiertos dos PR de Dependabot anteriores: el #33 (setup-java) y el #34 (pandas). Los
ataja el issue #89.

**Consecuencia:** todo lo de los PR #114 a #126 (pantalla de leche, «Acerca del modelo», despliegue en
Render, arreglos sin conexión) todavía **no está en `main` ni en ninguna etiqueta**.

## 2. Pruebas, cobertura y mutación (última ejecución del CI en `develop`)

| Módulo | Pruebas | Cobertura de líneas | Cobertura de ramas | Fuente |
|---|---|---|---|---|
| backend (Java) | 202 ejecutadas, 0 fallos, 2 omitidas (llaman a Gemini en vivo) | 94,1 % (1232/1309) | 84,8 % (323/381) | Pruebas: flujo `backend`, ejecución [44115907121](https://github.com/Pipemora1324/Agrovet/actions/runs/44115907121) (`99154ff`). Cobertura: flujo `calidad`, [44190122329](https://github.com/Pipemora1324/Agrovet/actions/runs/44190122329) (`54ce15d`) |
| ml (Python) | 210 pasan | 79,6 % (1685/2117) | 75,2 % (355/472) | Pruebas: flujo `ml`, [44115683283](https://github.com/Pipemora1324/Agrovet/actions/runs/44115683283) (`22770c0`). Cobertura: flujo `calidad`, 44190122329 |
| mobile (Dart) | 238 pasan | 76,9 % (3933/5113) | no se mide (Flutter no mide ramas) | Flujo `mobile`, [44190122503](https://github.com/Pipemora1324/Agrovet/actions/runs/44190122503) (`54ce15d`). Cobertura: flujo `calidad`, 44190122329 |

La cobertura se calculó con el mismo script del CI (`scripts/ci/coverage_summary.py`) sobre los
artefactos `cobertura-backend`, `cobertura-ml` y `cobertura-mobile` de la ejecución 44190122329. Los
flujos `backend` y `ml` no corrieron después del PR #126 porque ese PR no toca esas carpetas. Por eso
sus últimas ejecuciones son de commits anteriores con el mismo código de backend y de ml.

**Mutación** (flujo `mutacion`, ejecución [44115907085](https://github.com/Pipemora1324/Agrovet/actions/runs/44115907085),
`99154ff`, artefactos `pit` y `mutmut`, resumidos con `scripts/ci/mutation_summary.py`):

| Herramienta | Alcance | Resultado | Umbral |
|---|---|---|---|
| PIT | Backend: paquetes `auth` y `sync` | 100,0 % (313 de 313 mutantes eliminados) | 90 % (`backend/pom.xml`) |
| mutmut | ml: lógica pura (módulos en `[tool.mutmut]` de `ml/pyproject.toml`) | 94,9 % (1422 de 1499). Sobreviven 77: `lstm_evaluation` 29, `cnn_evaluation` 15, `build_cnn_dataset` 14, `milk_evaluation` 13, `preprocess` 6 | 90 % (`--min 90`) |

**Qué mide cada cosa:**
- **Cobertura de líneas:** qué parte del código se ejecuta al menos una vez durante las pruebas.
  Una línea sin cubrir no se probó; una línea cubierta no garantiza que esté bien.
- **Cobertura de ramas:** en cada `if` o `switch`, si las pruebas recorren todos los caminos posibles
  (el «sí» y el «no»).
- **Mutación:** la herramienta mete errores pequeños a propósito en el código (cambia un `<` por
  `<=`, borra una línea, invierte una condición) y vuelve a correr las pruebas. Si alguna prueba
  falla, el «mutante» quedó eliminado. El porcentaje dice qué tan buenas son las pruebas para
  detectar errores reales, no solo cuánto código recorren.

## 3. SonarCloud

Consultado el 2026-11-18 con la API pública de SonarCloud (`api/qualitygates/project_status`,
`api/measures/component`, `api/issues/search`), proyecto `Pipemora1324_Agrovet`.

**Quality Gate**

| Rama | Estado | Condiciones (sobre el código nuevo) |
|---|---|---|
| `develop` | **Aprobado (OK)** | Fiabilidad A (≤ 1) ✓, seguridad A ✓, mantenibilidad A ✓, cobertura ≥ 80 % → **94,0 %** ✓, duplicación ≤ 3 % → **0,0 %** ✓, hotspots revisados = 100 % → **100 %** ✓ |
| `main` | **Sin evaluar (NONE)**: SonarCloud no calcula condiciones de código nuevo para esa rama. Último análisis: 2026-11-16 (`dcad510`) | — |

**Medidas generales del último análisis**

| Medida | `main` (`dcad510`) | `develop` |
|---|---|---|
| Errores (bugs) | 3 | 0 |
| Vulnerabilidades | 6 | 0 |
| Calificación de fiabilidad / seguridad / mantenibilidad | E / D / A | A / A / A |
| Cobertura (líneas / ramas) | 78,2 % / 79,1 % | 80,0 % / 79,5 % |
| Duplicación | 0,2 % | 0,1 % |
| Hotspots de seguridad | 0 (100 % revisados) | 0 (100 % revisados) |
| Code smells | 3669 | 282 |
| Líneas de código analizadas | 22 719 | 5 838 |

La gran diferencia entre `main` y `develop` en líneas analizadas y en code smells **no está
explicada**. `sonar-project.properties` solo cambió en `sonar.coverage.exclusions` entre las dos ramas
(`git diff origin/main origin/develop -- sonar-project.properties`). Habría que revisarlo en el panel
de SonarCloud antes de citar esas dos cifras en la tesis.

**Los 9 hallazgos antiguos de `main`** (todos siguen abiertos en `main`, porque `main` no cambió desde
v0.2.0; detalle en [pruebas/sonar_hallazgos_main.md](pruebas/sonar_hallazgos_main.md) y en el PR #116):

| Regla | Archivo | Estado |
|---|---|---|
| `java:S2077` (SQL armado con texto) | `AccountDeletionService.java` | **Corregido** en `develop` (#116) |
| `java:S2184` (desbordamiento de enteros) | `CowService.java` | **Corregido** en `develop` (#116) |
| `kotlin:S7204` (R8 implícito) | `build.gradle.kts` | **Corregido** en `develop` (#116) |
| `python:S5863` (comparación consigo mismo) | `test_train_lstm.py` | **Corregido** en `develop` (#116) |
| `java:S4502` (CSRF apagado) | `SecurityConfig.java` | Falso positivo propuesto: **espera tu aprobación** |
| `java:S2068` (posible clave en el código) | `AuthService.java` (`WRONG_PASSWORD`) | Falso positivo propuesto: **espera tu aprobación** |
| `plsql:DeleteOrUpdateWithoutWhereCheck` | migración `V7__email_verification.sql` | Falso positivo propuesto (intencional): **espera tu aprobación** |
| `xml:S5332` (tráfico sin cifrar) | manifiesto de debug | Falso positivo propuesto: **espera tu aprobación** |
| `xml:S6358` (copia de seguridad) | manifiesto de debug | Falso positivo propuesto: **espera tu aprobación** |

En `develop`, SonarCloud muestra **0 errores y 0 vulnerabilidades abiertas**. Los cinco falsos
positivos propuestos no figuran como abiertos ni como resueltos en esa rama. No se marcaron a mano
en ningún momento.

**Qué mide cada métrica:**
- **Fiabilidad (bugs):** errores que pueden hacer que el programa falle o dé un resultado incorrecto.
  A significa ninguno; E, al menos uno grave.
- **Seguridad (vulnerabilidades):** código que un atacante podría aprovechar.
- **Mantenibilidad (code smells):** código que funciona pero es difícil de leer o de cambiar.
- **Hotspots de seguridad:** partes delicadas (criptografía, permisos) que una persona debe revisar
  y confirmar que están bien.
- **Duplicación:** porcentaje de líneas copiadas en más de un sitio.
- **Código nuevo:** el Quality Gate de `develop` evalúa solo lo que cambió respecto a la referencia.
  Así se exige calidad a lo nuevo sin bloquear por deudas antiguas.

## 4. Los 9 flujos de CI

Fuente: `.github/workflows/*.yml` y `gh run list --workflow <flujo>` (2026-11-18).

| Flujo | Cuándo corre | Qué verifica | Último resultado en `develop` | Último en `main` |
|---|---|---|---|---|
| `backend` | push y PR a `main`/`develop` que tocan `backend/` | `./mvnw verify`: compila con Java 21, pruebas JUnit con Testcontainers (PostgreSQL real), Checkstyle, SpotBugs y cobertura JaCoCo | ✅ 17-11 (`99154ff`) | ✅ 16-11 (`dcad510`) |
| `ml` | push y PR que tocan `ml/` | ruff (estilo), mypy (tipos) y pytest con cobertura | ✅ 17-11 (`22770c0`) | ✅ 16-11 |
| `mobile` | push y PR que tocan `mobile/` o los modelos | `flutter analyze` estricto, `flutter test` con cobertura, APK por arquitectura con límite de 15 MB, APK normal sin modelos experimentales y APK de demostración (arm64) | ✅ 17-11 (`54ce15d`) | ✅ 16-11 |
| `mutacion` | push y PR que tocan el código de backend o ml; cada lunes; a mano | PIT en `auth` y `sync` y mutmut en ml, con un mínimo del 90 % | ✅ 17-11 (`99154ff`) | ✅ 16-11 |
| `calidad` | push y PR a `main`/`develop`; a mano | Cobertura de los 3 módulos, resumen en el PR y análisis de SonarCloud con su Quality Gate | ✅ 17-11 (`54ce15d`) | ✅ 16-11 |
| `codeql` | push y PR; cada lunes | Análisis de seguridad de GitHub (Java/Kotlin, Python y los propios flujos) | ✅ 17-11 (`54ce15d`) | ✅ 16-11 |
| `dependency-review` | push y PR a `main`/`develop` | Que ninguna dependencia nueva traiga vulnerabilidades de severidad moderada o más | ✅ 17-11 (`54ce15d`) | ✅ 16-11 |
| `seguridad` | push y PR; cada lunes | gitleaks (secretos en todo el historial) y Trivy (Dockerfile y compose; falla con HIGH o CRITICAL) | ✅ 17-11 (`54ce15d`) | ✅ 16-11 |
| `scorecard` | push a `main`, cambios en protección de ramas, cada lunes | OpenSSF Scorecard: buenas prácticas de seguridad del repositorio | no corre en `develop` | ✅ 16-11 |

Todas las acciones están fijadas por SHA y los flujos tienen permisos de solo lectura por defecto
(`contents: read`). Las ramas todavía **no exigen** que estos checks pasen antes de integrar: es el
issue #22, abierto.

## 5. APK: tamaños y versiones

| APK | Versión | Tamaño | Fuente |
|---|---|---|---|
| Release normal arm64 | 0.2.0 (código 2002) | 13,0 MiB (13,7 MB según Flutter) | Flujo `mobile`, 44190122503, paso «Tamaño de los APK» |
| Release normal armeabi-v7a | 0.2.0 | 12,1 MiB | ídem |
| Release normal x86_64 | 0.2.0 | 14,0 MiB (14,7 MB según Flutter) | ídem |
| Demostración arm64 del CI (sin servidor, con modelos experimentales) | 0.2.0 | 15,4 MB según Flutter (bajo el límite de 15 MiB que revisa el paso) | ídem, paso «APK de demostración (arm64)» |
| Demostración **con servidor** (Render) | 0.2.2 (código 2004) | 15 445 421 bytes (14,7 MiB) | Compilado a mano el 2026-11-17 con `mobile/tool/build_demo_apk.ps1` desde el PR #126; `aapt2 dump badging` |
| Demostración **sin servidor** (respaldo) | 0.2.2 (código 2004) | 15 434 041 bytes (14,7 MiB) | ídem |

Las dos APK 0.2.2 no son una etiqueta ni una versión publicada: llevan un número de versión mayor solo
para instalarse encima de las anteriores. El límite del CI es de 15 MiB por APK.

## 6. Backend de demostración en Render

| Dato | Valor | Fuente |
|---|---|---|
| Creación de la base | **2026-11-17**: las 13 migraciones Flyway se aplicaron entre las 16:09:39 y las 16:09:41 (hora del servidor de base de datos) | Consulta de solo lectura a `flyway_schema_history` (2026-11-18) |
| Vencimiento de la base gratuita | 30 días después de crearla: **alrededor del 2026-12-17**. Luego hay 14 días para pasarla a un plan pago antes de que se borre | Regla del plan gratuito de Render ([docs/DEPLOY_RENDER.md](../DEPLOY_RENDER.md)). **La fecha exacta hay que confirmarla en el panel** |
| Creación del servicio web | **No verificado** desde aquí (no hay acceso al panel). El primer arranque con la base es la fecha de las migraciones (17-11) | — |
| PostgreSQL | 15.20 | `current_setting('server_version')` |
| Datos | 1 usuario de demostración, 6 vacas sintéticas, 126 registros | Consulta de solo lectura (2026-11-18) |
| Arranque | Local con los mismos límites (512 MB, 0,1 CPU): **168 s**. En Render, al despertar después de dormirse, la primera respuesta tardó **89–95 s** (cuatro mediciones con `curl` del 17 y 18-11) | `docs/DEPLOY_RENDER.md`; `curl -w %{time_total}` a `/actuator/health` |

**Qué funciona:** ingreso con cuenta real, vacas, historial, sincronización, restauración de vacas y
registros en otro celular, asistente con Gemini y subida de fotos. Se verificó en local con los mismos
límites y, en Render, con la salud del servidor y con un ingreso con contraseña incorrecta, que
respondió 401.

**Qué no funciona o tiene límites:**
- **Correo:** el plan gratuito bloquea el SMTP. El código de verificación no llega y las cuentas nuevas
  se verifican a mano con `backend/deploy/render/verify_account.ps1`.
- **Fotos:** el disco es efímero, así que las fotos se pierden cuando el servicio se duerme o se
  redespliega. La app tampoco las restaura en otro celular (issue #91).
- **Se duerme:** tras 15 minutos sin uso; el primer pedido después tarda cerca de un minuto y medio.
- No es el servidor definitivo: la VPS con HTTPS (issue #88) no está desplegada.

## 7. Issues de seguimiento y sprints

Fuente: `gh issue view` y `gh api repos/.../milestones` (2026-11-18).

| Issue | Estado | Sprint | Qué falta |
|---|---|---|---|
| #22 RNF-06 Integración continua por módulo | Abierto | Sprint 3 | Exigir los checks del CI con protección de ramas |
| #88 Desplegar el backend en una VPS con HTTPS | Abierto | Sprint 3 | Solo existe la demostración en Render |
| #89 Aplicar las actualizaciones de Dependabot #33 y #34 | Abierto | Sprint 3 | Siguen abiertos el #33, el #34 y otros cinco nuevos (#119–#123) |
| #90 Confirmar los datos del responsable en el aviso de privacidad | Abierto | Sprint 3 | Confirmación tuya |

**Sprint 3** (2026-11-10 a 2026-11-23): 16 cerrados y 4 abiertos (#22, #88, #89, #90).

**Sprint 4** (planificado, 2026-11-24 a 2026-12-07): 5 abiertos.
- #17 RNF-02: interfaz para trabajo de campo (falta un celular de gama baja real).
- #91 Recuperar las fotos al restaurar.
- #92 Revisión veterinaria del puntaje por síntomas.
- #93 Prueba de campo con ganaderos de Nariño.
- #94 Escala de usabilidad SUS.
- #95 Fotos de ubre confirmadas por un veterinario.

GitHub cuenta 5 abiertos en ese milestone, pero la lista trae 6 issues; la diferencia no está
explicada.

**Sprint 5** (planificado, 2026-12-08 a 2026-12-21): 3 abiertos.
- #11 RF-10: triaje visual de la ubre.
- #96 Máscara para datos faltantes en el LSTM y evaluación con datos reales.
- #97 Resultados, discusión y conclusiones.
- #98 Sustentación y versión final.

Igual que en el sprint 4, GitHub cuenta 3 abiertos pero la lista trae 4.

## 8. Requisitos y pruebas que los respaldan

Base: [pruebas/trazabilidad.md](pruebas/trazabilidad.md). El 2026-11-18 se comprobó con `grep` que
cada prueba nombrada sigue existiendo en `develop` (`54ce15d`). El estado de cada issue viene de
`gh issue list`. «CI ✅» se refiere a las ejecuciones de `develop` de la sección 2.

| Req. | Issue | Estado | Pruebas que lo respaldan | Resultado |
|---|---|---|---|---|
| RF-01 Registro e inicio de sesión | #1 | Cerrado | `AuthIntegrationTest.refreshRotatesAndReuseRevokesFamily`, `registerCreatesUnverifiedAccountAndEmailsCodeStoredOnlyAsHmac` | CI ✅ |
| RF-02 Registro y edición de bovinos | #2 | Cerrado | `CowIntegrationTest.crudFlow`, `listShowsOnlyOwnCows` | CI ✅ |
| RF-03 Captura diaria con validación | #3 | Cerrado | `SyncIntegrationTest.invalidValuesAreRejectedWithBadRequest`, `secondRecordForSameDayIsRejected`; `domain_test.dart` | CI ✅ |
| RF-04 Historial con gráficas | #4 | Cerrado | `CowIntegrationTest.historyReturnsRecordsInRange` | CI ✅ |
| RF-05 Inferencia LSTM sin conexión | #5 | Cerrado | `test/model/test_vectors_test.dart`; `integration_test/test_vectors_on_device_test.dart` | CI ✅ + emulador |
| RF-06 Semáforo con recomendación | #6 | Cerrado | `widgets_test.dart` «el resultado muestra el semáforo, la recomendación y el aviso fijo» | CI ✅ |
| RF-07 Inferencias y alertas | #7 | Cerrado | `local_repository_test.dart`; `SyncIntegrationTest.alertMarkedAsAttendedIsUpdatedAndShownInHistory` | CI ✅ |
| RF-08 Sincronización idempotente | #9 | Cerrado | `SyncIntegrationTest.sameBatchTwiceCreatesNoDuplicates`, `olderVersionDoesNotOverwriteNewerOne`, `otherUserCannotOverwriteOrAttachToForeignData`; `restore_service_test.dart` | CI ✅ |
| RF-09 Sincronización en segundo plano | #10 | Cerrado | `sync_service_test.dart`; `sync_cubit_test.dart` | CI ✅ + emulador |
| RF-10 Triaje visual con foto | #11 | **Abierto** | `test_build_cnn_dataset.py`, `test_train_cnn.py`, `test_cnn_evaluation.py`, `test_udder_tflite_parity.py`; `udder_triage_card_test.dart` | ⚠️ Parcial: pruebas en verde, CNN no validada; solo en el APK de demostración |
| RF-11 Dataset sintético | #12 | Cerrado | `test_generate_dataset.py::test_exactly_35_percent_of_cows_get_sick` | CI ✅ |
| RF-12 Entrenamiento y evaluación del LSTM | #13 | Cerrado | `test_train_lstm.py::test_split_has_no_cow_leakage_and_is_stratified` | CI ✅ (métricas sintéticas) |
| RF-13 Exportación TFLite y vectores | #15 | Cerrado | `test_exported_model.py::test_model_uses_only_builtin_ops`, `test_tflite_reproduces_vectors` | CI ✅ |
| RF-14 Verificación de correo y recuperación | #28 | Cerrado | `AuthIntegrationTest.loginIsRefusedUntilEmailIsVerified`; `MailServerConfigTest`; `auth_test.dart` | CI ✅. En Render el correo no sale (sección 6) |
| RF-15 Perfil, eliminación y consentimiento | #29 | Cerrado | `ProfileIntegrationTest`; `profile_test.dart` | CI ✅ |
| RF-16 Registro flexible y puntaje por síntomas | #30 | Cerrado | `symptom_score_test.dart`; `cubits_test.dart`; `record_wizard_test.dart`; `SyncIntegrationTest.valueSourcesAreStoredShownAndValidated` | CI ✅; reglas provisionales (#92) |
| RF-17 Fotos de la ubre por vaca | #31 | Cerrado | `PhotoIntegrationTest`; `PhotoProcessorTest`; `photos_test.dart`; `photo_view_test.dart` | CI ✅; las fotos no se restauran (#91) |
| RF-18 Asistente con IA | #32 | Cerrado | `AssistantIntegrationTest`; `GeminiClientTest`; `WaitTextTest`; `assistant_test.dart` (incluye los casos sin conexión del #126) | CI ✅ |
| RNF-01 Funcionamiento sin conexión | #16 | Cerrado | `sync_service_test.dart`; `api_errors_test.dart`; `auth_test.dart`, grupo «sin conexión»; `cubits_test.dart`, grupo «guardar sin conexión» | CI ✅ + emulador en modo avión |
| RNF-02 Interfaz para trabajo de campo | #17 | **Abierto** | `theme_test.dart`; `responsive_test.dart`; `record_wizard_test.dart`; `photo_view_test.dart`; `architecture_test.dart` | ⚠️ Parcial: falta un celular de gama baja real |
| RNF-03 Seguridad de la API | #18 | Cerrado | `AuthIntegrationTest.loginIsRateLimited`, `tokenSignedWithOtherKeyIsRejected`, `corsAllowsOnlyConfiguredOrigins`; `CowIntegrationTest.sqlInjectionInTagIsStoredAsPlainText`, `otherUserCannotReadUpdateDeleteOrSeeHistory`; `ProdProfileIntegrationTest`; `CorsPropertiesTest`; `LoginRateLimiterTest` | CI ✅ |
| RNF-04 Paridad Python / Dart | #19 | Cerrado | `test/model/test_vectors_test.dart`; `test_preprocess.py` | CI ✅ + emulador |
| RNF-05 Compatibilidad Android | #21 | Cerrado | Paso del flujo `mobile` que falla si un APK pasa de 15 MiB | CI ✅ (sección 5) |
| RNF-06 Integración continua por módulo | #22 | **Abierto** | Los 9 flujos de la sección 4 | ⚠️ Parcial: falta exigir los checks con protección de ramas |
| RNF-07 Documentación de la API | #23 | Cerrado | `AuthIntegrationTest.swaggerIsAvailable`; `ProdProfileIntegrationTest` | CI ✅ |
| RNF-08 Datos protegidos en el celular | #24 | Cerrado | `encrypted_database_test.dart` | CI ✅ |

**Fuera de los requisitos:**
- **Leche (experimental):** solo en el APK de demostración. La respaldan `milk_check_test.dart` y
  `milk_model_test.dart`.
- **«Acerca del modelo»:** la respalda `model_facts_test.dart`, que exige que cada cifra esté en
  `ml/README.md`.
- **Despliegue en Render:** lo respalda `DatabaseUrlEnvironmentPostProcessorTest`.

## 9. Lo que la tesis **no puede afirmar** todavía

1. **Que el LSTM cumple la hipótesis F1 ≥ 0,80.** Todas sus métricas salen de datos sintéticos (F1 de
   prueba 0,492, AUC 0,891) y no validan la hipótesis (`ml/README.md`). Tampoco hay evaluación con
   datos reales de fincas (#96).
2. **Que el LSTM supera con claridad a modelos más simples.** Frente a la regresión logística y al
   random forest la ventaja en AUC es pequeña (unos 0,02–0,03), y en F1 frente al random forest no es
   significativa (`ml/README.md`, líneas base).
3. **Que el modelo resiste días sin registro.** Con 2 días faltantes el F1 baja de 0,49 a 0,16; con 4,
   el AUC queda en 0,52, como el azar (`ml/README.md`, robustez).
4. **Que el triaje visual de la ubre (CNN) funciona.** Se entrenó con un dataset público cuyas
   etiquetas no confirmó un veterinario y con sesgo de fondo. Está apagado en la app normal (RF-10 #11
   abierto, #95).
5. **Que el clasificador de leche sirve en campo.** Se evaluó con un único conjunto de datos público y
   solo existe como pantalla experimental en la demostración.
6. **Que el puntaje por síntomas y las equivalencias están validados por un veterinario** (#92
   abierto).
7. **Que la app es usable para los ganaderos de Nariño.** No hubo prueba de campo (#93) ni escala SUS
   (#94).
8. **Que funciona en un celular de gama baja real** (RNF-02 #17 abierto). Las pruebas se hicieron en
   emulador y en una tableta.
9. **Que hay un servidor de producción.** Solo existe la demostración gratuita en Render, sin correo,
   con fotos efímeras y con una base que vence. La VPS con HTTPS (#88) no está desplegada.
10. **Que las fotos se recuperan en otro celular** (#91 abierto).
11. **Que el asistente da consejos correctos en general.** La evaluación con la API real
    ([pruebas/asistente.md](pruebas/asistente.md), 2026-11-16) usa 30 preguntas escritas para el
    proyecto, con criterios propios y sin revisión veterinaria. El asistente orienta y no diagnostica.
12. **Que la versión con los cambios de los PR #114 a #126 está entregada.** Esos cambios están solo
    en `develop`; `main` y la etiqueta `v0.2.0` son anteriores.
13. **Que el código cumple las reglas de SonarCloud en `main`.** `main` conserva los 9 hallazgos
    antiguos: 4 están corregidos en `develop` y 5 esperan tu decisión.
14. **Que el aviso de privacidad tiene los datos definitivos del responsable** (#90 abierto).
