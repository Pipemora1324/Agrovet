# Calidad del código y de las pruebas

Qué herramientas revisan el repositorio, dónde corren, qué rompe el build y qué resultados dieron.
Los números de este documento son de la corrida local del 2026-11-15 en la rama
`feature/calidad-ci`; las corridas del CI quedan enlazadas en el pull request que la integra.

## Resumen

| Aspecto | Herramienta | Módulo | Dónde corre | Rompe el build si… |
|---|---|---|---|---|
| Cobertura | JaCoCo 0.8.16 | backend | `backend`, `calidad` | — (se informa) |
| Cobertura | pytest-cov 7.1 | ml | `ml`, `calidad` | — (se informa) |
| Cobertura | `flutter test --coverage` | mobile | `mobile`, `calidad` | — (se informa) |
| Mutación | PIT 1.30 (+ JUnit 5) | backend `auth` y `sync` | `mutacion` | elimina menos del 90 % |
| Mutación | mutmut 3.8 | ml (lógica pura) | `mutacion` | elimina menos del 90 % |
| Estilo | Checkstyle 14.4 | backend | `backend` (`./mvnw verify`) | hay una violación |
| Errores probables | SpotBugs 4.10 + FindSecBugs 1.14 | backend | `backend` (`./mvnw verify`) | hay un hallazgo Medium o mayor |
| Estilo | ruff 0.17 | ml y `scripts/ci` | `ml` | hay un hallazgo |
| Tipos | mypy 2.4 | ml (`--strict` en `scripts/ci`) | `ml` | hay un error |
| Análisis estático | `flutter analyze` en modo estricto | mobile | `mobile` | hay un info, warning o error |
| Calidad general | SonarCloud | los tres | `calidad` | — (Quality Gate en SonarCloud) |
| Seguridad del código | CodeQL | Java, Python y workflows | `codeql` | — (alertas en Security) |
| Secretos | gitleaks 8.30.1 | todo el historial | `seguridad` | aparece un secreto |
| Configuración | Trivy 0.76.2 | Dockerfile y compose | `seguridad` | hay un hallazgo HIGH o CRITICAL |
| Prácticas del repositorio | OpenSSF Scorecard 2.5 | repositorio | `scorecard` (solo `main`) | — (resultado en Security) |

## Resultados

### Pruebas y cobertura

| Módulo | Pruebas | Líneas | Ramas |
|---|---|---|---|
| backend | **169** (1 omitida: `GeminiLiveTest`); antes 104 | **93,9 %** (1191/1268) | **85,2 %** (299/351) |
| ml | **113**; antes 80 | **62,2 %** (713/1146) | **57,3 %** (150/262) |
| mobile | **188** | **75,0 %** (3394/4526) sin el código generado | Flutter no mide ramas |

- **mobile**: con `app_database.g.dart` (código que genera Drift) la cifra baja a 54,0 % (4428/8193).
  Ese archivo no se escribe a mano, así que se excluye del resumen y de SonarCloud.
- **ml**: lo que no se cubre son sobre todo los `main()` de entrenamiento y exportación
  (`train_lstm.py`, `train_udder_public.py`, `export_tflite.py`, `export_test_vectors.py`), que se
  ejecutan a mano con datos reales y TensorFlow. La lógica que usan está probada por separado:
  `preprocess.py` y `cnn_evaluation.py` quedan en 100 %, `build_cnn_dataset.py` en 97 % y
  `udder_public_data.py` en 96 %.

### Pruebas de mutación

Una prueba de mutación cambia el código a propósito (por ejemplo, `>=` por `>`, o borra una llamada)
y comprueba que alguna prueba falle. Un mutante que sobrevive señala una regla que ninguna prueba
verifica.

| Módulo | Antes | Después | Pruebas nuevas |
|---|---|---|---|
| backend `auth` y `sync` (PIT) | 21,9 % (68/310), 221 sin cobertura | **100 %** (313/313) | `SyncServiceTest` (25), `EmailCodeServiceTest` (9), `TokenServiceTest` (4) y 27 casos más en `AuthServiceTest`, `LoginRateLimiterTest` y `CodeRequestLimiterTest` |
| ml (mutmut) | 73,5 % (454/618), 49 sin pruebas | **94,3 %** (583/618) | `test_preprocess_limits.py`, `test_cnn_evaluation_limits.py`, `test_build_cnn_dataset_limits.py` |

**Por qué el backend partía tan bajo.** `SyncService` y `EmailCodeService` solo tenían pruebas de
integración (Spring + PostgreSQL). PIT usa solo pruebas unitarias: con las de integración levantaría
Spring y la base por cada uno de los 313 mutantes. Las pruebas nuevas cubren con Mockito las mismas
reglas: dueño de cada elemento, "gana la última modificación" con el caso del mismo instante, nombres
duplicados, alertas verdes, foto borrada que borra el archivo, HMAC del código atado al usuario y al
propósito, intentos fallidos, vencimiento exacto del refresh token, y la limpieza de memoria de los
dos limitadores al pasar de 10 000 entradas.

**Huecos reales que encontró la mutación** (las pruebas viejas pasaban con el código mutado):

- Nadie probaba que un registro, inferencia, alerta o foto *ya guardados* se actualizaran con una
  versión más nueva; solo se probaba la creación.
- `AuthService.refresh` con un token vencido fallaba igual por otra razón (el usuario del mock no
  existía), así que quitar la comprobación de vencimiento no rompía ninguna prueba.
- El límite de memoria de `LoginRateLimiter` y `CodeRequestLimiter` (limpieza al pasar de 10 000
  entradas) no tenía ninguna prueba. Para observarla se agregaron `trackedKeys()`, `trackedEmails()`
  y `trackedIps()`, de solo lectura y visibles solo dentro del paquete.
- En `ml`, los límites exactos de los rangos válidos (35 y 42 °C, 0,5 y 45 L, 0,5 y 35 kg), el
  mínimo de 10 días válidos y el horizonte de 1 a 5 días de la etiqueta: cambiar `<=` por `<` no
  rompía nada. La app replica esta lógica en Dart, así que un error de un día cambia la alerta.
- `build_dataset` seguía funcionando si el `continue` de una fila inválida se cambiaba por `break`:
  una sola fila mala en el manifiesto habría dejado fuera todas las fotos siguientes.

**Los 35 mutantes de ml que sobreviven** se revisaron uno por uno. Ninguno cambia un resultado que
se pueda observar con datos válidos:

| Mutantes | Cambio | Por qué no se puede detectar |
|---|---|---|
| 3 | `groupby("cow_id", sort=…)` | los datos ya vienen ordenados por `sort_values` en la línea anterior |
| 1 | `to_numpy(dtype=None)` | `clean_window` convierte a `float64` de todos modos |
| 2 | `iloc[1]` en vez de `iloc[0]` para `sick` y `onset_day` | son constantes por vaca |
| 1 | `bincount(minlength=3)` | solo se leen las clases 0 y 1 |
| 2 | `float("NAN")` | es lo mismo que `float("nan")` |
| 1 | `min(2.0, …)` en el intervalo de Wilson | el extremo superior nunca pasa de 1 |
| 1 | `rng.choice` sin `replace=True` | `True` es el valor por defecto |
| 2 | `summarize` con `n_boot=2001` o `.astype(None)` | diferencia de una muestra en 2000; `True == 1` en NumPy |
| 8 | rama de `summarize` sin positivos o sin negativos | inalcanzable: `roc_auc_score` exige las dos clases y falla antes |
| 8 | `encoding=None` o `"UTF-8"`, `newline` en `build_dataset` | en Linux la codificación por defecto ya es UTF-8; el CSV no tiene saltos de línea entre comillas |
| 6 | texto de ayuda en mayúsculas, `type=Path` en `--manifest`, `ensure_ascii` | `open()` acepta texto; el resumen solo tiene caracteres ASCII |

### Linters

| Herramienta | Hallazgos al activarla | Cómo quedó |
|---|---|---|
| Checkstyle | 23 | 0: 18 líneas largas partidas, 1 import sin usar, 2 sangrías; 2 reglas ajustadas (abajo) |
| SpotBugs + FindSecBugs | 39 | 0: 1 corrección y 3 exclusiones justificadas en `backend/config/spotbugs-exclude.xml` |
| ruff | 9 con las reglas elegidas | 0: 7 bloques de imports ordenados, 1 `noqa` de más y 1 variable sin usar; 3 reglas ignoradas (abajo) |
| mypy | 16 | 0: anotaciones de diccionarios, constantes de Pillow por su enum (`Image.Resampling.BILINEAR`, mismo valor) y `dtype=np.float64` en vez de `float` (el mismo tipo) |
| `flutter analyze` estricto | 19 | 0: `MaterialPageRoute<void>` en 13 rutas y tipos explícitos en 6 listas vacías |

Decisiones:

- **Checkstyle** parte del estilo que ya sigue el código (4 espacios, 120 columnas) y agrega las
  reglas que previenen errores: llaves obligatorias, `equals` con `hashCode`, sin `catch` vacíos ni
  caídas entre casos de un `switch`. No usa `MissingSwitchDefault`: en Java 21 un `switch` sobre un
  enum se deja sin `default` para que el compilador avise si aparece un valor nuevo. La clase
  `@SpringBootApplication` queda fuera de `HideUtilityClassConstructor` porque Spring la instancia.
- **SpotBugs**: se corrigió un `catch (NullPointerException)` en `GeminiClient.retryAfter` que era
  código muerto (`Long.parseLong(null)` lanza `NumberFormatException`); ahora hay un `if` explícito
  con el mismo resultado. Se excluyen `EI_EXPOSE_REP`/`EI_EXPOSE_REP2` (beans inyectados por Spring y
  records de DTO; copiar las listas cambiaría el comportamiento porque `List.copyOf` rechaza `null`),
  `CT_CONSTRUCTOR_THROW` en dos beans que fallan a propósito al arrancar, y la concatenación de un
  nombre de tabla constante en `AccountDeletionService` (el id siempre va como parámetro).
- **ruff** reemplaza a flake8 (cubre sus reglas y más). Se ignoran `N803`/`N806` (`X`, `y`: convención
  de ML), `RUF046` (los `int(...)` convierten tipos de NumPy antes de pasar a JSON) y `B905`
  (`zip(strict=True)` cambiaría el comportamiento).
- **Dart estricto**: `strict-casts`, `strict-inference` y `strict-raw-types` en
  `mobile/analysis_options.yaml`, y `--fatal-infos` en el CI.

### Seguridad

| Herramienta | Resultado local | Notas |
|---|---|---|
| gitleaks (historial, 180 commits) | 0 | 3 apariciones del secreto JWT de prueba de `application-test.yml` (en Base64 dice "test-secret-solo-para-pruebas-…") quedan exceptuadas en `.gitleaks.toml`, solo para ese archivo y ese valor |
| Trivy (`backend/`) | 0 HIGH/CRITICAL | 1 LOW aceptado en `backend/.trivyignore`: `DS-0026` (falta `HEALTHCHECK`); el chequeo de salud está en `docker-compose.prod.yml` |
| actionlint y zizmor (workflows) | 0 | zizmor encontró un `checkout` sin `persist-credentials: false` en `dependency-review.yml`; corregido |
| CodeQL, Scorecard | — | solo corren en GitHub |

**Trivy y el incidente de marzo de 2026.** El aviso de seguridad de `aquasecurity/trivy` (crítico,
2026-03-21) informa que el 19 de marzo se publicó un Trivy v0.69.4 malicioso y se reescribieron 76 de
77 etiquetas de `trivy-action`. Por eso se usa `trivy-action` **v0.36.0** (publicada el 2026-04-22, con
release inmutable) fijada por SHA, y el binario fijado en **v0.76.2**, nunca `latest`.

**gitleaks** se instala desde el binario de la release y se verifica su SHA-256 antes de ejecutarlo,
en vez de usar una action de terceros.

## Workflows

Todos tienen `permissions: contents: read` arriba; los jobs que suben resultados piden solo lo que
necesitan. Todas las actions van fijadas por SHA con la versión en un comentario (Dependabot las
actualiza cada semana) y todos los `checkout` usan `persist-credentials: false`.

| Workflow | Cuándo | Permisos extra por job | Qué hace |
|---|---|---|---|
| `backend` | push/PR con cambios en `backend/` | — | `./mvnw verify`: pruebas, JaCoCo, Checkstyle, SpotBugs; resumen de cobertura |
| `ml` | push/PR con cambios en `ml/` | — | ruff, mypy, pytest con cobertura |
| `mobile` | push/PR con cambios en `mobile/` | — | análisis estricto, pruebas con cobertura, APK ≤ 15 MB |
| `calidad` | todo push/PR a `main` y `develop` | `pull-requests: write` (job del comentario) | cobertura de los tres módulos, un comentario en el PR que se actualiza en cada push, SonarCloud |
| `mutacion` | push/PR con cambios en el código, cada lunes y a mano | — | PIT y mutmut con umbral de 90 % |
| `codeql` | push/PR y cada lunes | `security-events: write` | Java, Python y los workflows |
| `seguridad` | push/PR y cada lunes | `security-events: write` | gitleaks y Trivy, con SARIF en la pestaña Security |
| `scorecard` | push a `main`, cada lunes y al cambiar la protección de ramas | `security-events: write`, `id-token: write`, `actions: read` | OpenSSF Scorecard |
| `dependency-review` | push/PR | — | sin cambios (solo `persist-credentials: false`) |

`calidad` repite las pruebas que ya corren los workflows de cada módulo. Es a propósito: los de
módulo dan la señal rápida con filtro por ruta, y `calidad` necesita los tres informes en cada cambio
para que SonarCloud analice el repositorio completo.

## SonarCloud: configuración pendiente

El análisis está listo en `sonar-project.properties` y en el job `sonarcloud` de `calidad`. Mientras
no exista el secreto, el job se salta con un aviso y no falla.

1. Entrar a [sonarcloud.io](https://sonarcloud.io) con la cuenta de GitHub e importar la organización
   `pipemora1324` (plan gratuito: el repositorio es público).
2. Crear el proyecto para `Pipemora1324/Agrovet`. Debe quedar con la clave `Pipemora1324_Agrovet`; si
   SonarCloud propone otra, cambiar `sonar.projectKey` y `sonar.organization` en
   `sonar-project.properties`.
3. En *Administration → Analysis Method*, **apagar "Automatic Analysis"**: si queda prendido, el
   análisis desde el CI falla.
4. En *My Account → Security*, generar un token.
5. En GitHub: *Settings → Secrets and variables → Actions → New repository secret*, nombre
   **`SONAR_TOKEN`**, valor el token del paso anterior.

## Cómo correr cada herramienta en local

Backend (JDK 21; Docker para las pruebas de integración):

```bash
cd backend
./mvnw verify                      # pruebas + JaCoCo (target/site/jacoco) + Checkstyle + SpotBugs
./mvnw test-compile org.pitest:pitest-maven:mutationCoverage   # PIT: target/pit-reports/index.html
```

ml (Python 3.13):

```bash
cd ml
pytest --cov --cov-report=term --cov-report=xml
ruff check src tests
mypy
```

mutmut no corre en Windows. En Linux, WSL o un contenedor:

```bash
cd ml
pip install numpy==2.5.4 pandas==3.1.0 scikit-learn==1.9.1 pytest==9.2.0 mutmut==3.8.1
mutmut run
mutmut results          # sobrevivientes;  mutmut show <nombre>  muestra el cambio
```

mobile:

```bash
cd mobile
flutter analyze --fatal-infos
flutter test --coverage            # coverage/lcov.info
```

Resúmenes como los del CI:

```bash
python scripts/ci/coverage_summary.py --jacoco backend/target/site/jacoco/jacoco.csv \
    --cobertura ml/coverage.xml --lcov mobile/coverage/lcov.info
python scripts/ci/mutation_summary.py --pit backend/target/pit-reports/mutations.xml
```

## Cambios en el código

Ninguno cambia el comportamiento de la app:

- Líneas partidas, un import sin usar y anotaciones de tipos (Checkstyle, mypy, Dart estricto).
- `GeminiClient.retryAfter`: `if (seconds == null)` en vez de capturar `NullPointerException`; mismo
  resultado (1 minuto).
- `LoginRateLimiter.trackedKeys()` y `CodeRequestLimiter.trackedEmails()`/`trackedIps()`: lectura del
  tamaño de los mapas, visibles solo en el paquete, para las pruebas.
- `preprocess.build_windows`: la lista de filas se llama `rows` antes de volverse el `DataFrame`
  `meta` (antes una variable cambiaba de tipo).
- Pillow: `Image.Resampling.BILINEAR`/`LANCZOS` y `Image.Transpose.FLIP_LEFT_RIGHT`, los mismos valores
  que las constantes antiguas.
- `photo_view_test.dart` y `udder_triage_card_test.dart` inicializan los datos de fecha en español.
  La foto de prueba tiene fecha fija (2026-11-09) y `formatDay` muestra "Hoy" o "Ayer" sin usar
  `DateFormat`: las 4 pruebas pasaron el día que se escribieron y empezaron a fallar dos días después
  en cualquier máquina, también en el CI. Ahora no dependen de la fecha.
