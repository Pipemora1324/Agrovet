# mobile — App Android de AgroVet

Aplicación Flutter (solo Android, API 24 o superior). El ganadero registra cada día temperatura,
leche, alimento y síntomas visibles de cada vaca; el modelo LSTM corre en el celular y muestra un
semáforo de riesgo. Todo funciona sin conexión.

> **Esta herramienta apoya, no reemplaza al veterinario.** El modelo actual se entrenó con datos
> simulados (ver `ml/README.md`); la app lo indica en la pantalla del resultado.

## Ejecutar

Requiere Flutter (canal estable) y un emulador o celular Android.

```bash
cd mobile
flutter pub get
flutter run
```

En la pantalla de ingreso de una compilación **debug** aparece el botón
**"Ver con datos de demostración"**: abre una sesión local con 6 vacas inventadas (prefijo `DEMO`)
y un rótulo amarillo "Datos de demostración" en todas las pantallas. Esos datos viven en una base
aparte, nunca se sincronizan y el botón no existe en las compilaciones release.

Para ingresar con una cuenta real, el backend debe estar corriendo (`backend/`, `docker compose up`).
Desde el emulador, la app lo busca en `http://10.0.2.2:8080`. Otra dirección se indica así:

```bash
flutter run --dart-define=API_BASE_URL=https://mi-servidor.example.org
```

En release solo se permite HTTPS: el permiso para HTTP sin cifrar existe únicamente en debug y
solo hacia `10.0.2.2` y `localhost`.

## Pruebas

```bash
flutter analyze
flutter test
# En el emulador o un celular conectado:
flutter test integration_test/test_vectors_on_device_test.dart -d <dispositivo>
```

- `test/model/test_vectors_test.dart` es la **prueba bloqueante**: la app reproduce los 8 casos de
  `ml/models/test_vectors.json` (normalización con tolerancia 1e-9 y probabilidad del modelo TFLite
  con 1e-4) y comprueba que el `.tflite` de la app es idéntico al exportado por `ml/`.
- La misma comparación se repite en el dispositivo con el intérprete nativo de Android.
  Su fixture se regenera con `dart run tool/generate_vector_fixture.dart`, y una prueba avisa si quedó
  desactualizado.
- `test/data/encrypted_database_test.dart` verifica que la base usa SQLCipher, que el archivo no se
  puede leer sin la clave y que una clave equivocada falla.

Al actualizar el modelo hay que copiar `ml/models/mastitis_lstm.tflite` y `model_config.json` a
`assets/model/` y regenerar el fixture; las pruebas fallan si se olvida.

## Estructura

```
lib/
  core/          tema, diseño adaptable, validaciones, formatos y configuración
  domain/        entidades, preprocesamiento (réplica de Python), semáforo, recomendaciones
  data/          base local (Drift + SQLCipher), almacenamiento seguro, API, modelo TFLite, demo
  presentation/  pantallas y cubits (login, vacas, registro diario, riesgo, historial)
```

## Seguridad

- **Base local cifrada** con SQLCipher. La clave son 32 bytes aleatorios por usuario guardados en el
  almacenamiento seguro de Android (Keystore, vía `flutter_secure_storage`); nunca está en el código.
  Si la biblioteca cargada no fuera SQLCipher, la app se niega a abrir la base.
- Cada usuario tiene su propio archivo de base y su propia clave.
- **Tokens** (acceso y refresh) solo en el almacenamiento seguro. El token de acceso se renueva
  automáticamente y, como el refresh token rota, la renovación se hace una sola vez aunque fallen
  varias llamadas a la vez.
- Respaldos de Android desactivados (`allowBackup=false` y reglas de extracción) para que la base y
  las claves no salgan del celular.
- Al cerrar sesión se borran los tokens, pero los datos cifrados se conservan para no perder lo que
  falte sincronizar.

## Sincronización

Todo se guarda primero en el celular; cada cambio queda marcado como pendiente.

- **Cuándo**: al abrir la sesión, al recuperar la conexión (`connectivity_plus`), cuando el ganadero
  toca la nube de la barra superior y cada 15 minutos en segundo plano con `workmanager` (solo con
  red; si falla, Android reintenta con espera exponencial).
- **Cómo**: `POST /api/sync` en lotes de hasta 200 elementos por tipo, primero las vacas. Ante fallas
  de red o del servidor se reintenta con espera exponencial (2, 4 y 8 s, con variación).
- **Confirmación**: solo se marca como sincronizado lo que el servidor confirma, y solo si la fila no
  cambió mientras se enviaba. Nunca se borra nada local.
- **Rechazos**: si el servidor rechaza un elemento (por ejemplo, otro registro para el mismo día), se
  guarda el motivo y no se reintenta hasta que el ganadero lo corrija.
- La nube muestra cuántos cambios faltan por subir. La sesión de demostración no sincroniza.

## Decisiones de diseño (para revisión)

- **Semáforo**: verde < 0,427; amarillo de 0,427 a < 0,854; rojo ≥ 0,854. Sale de `model_config.json`
  (umbral del modelo y su mitad); la justificación está en `ml/README.md`.
- **Faltan datos**: se evalúa con los últimos 14 días; un día sin registro cuenta como vacío. Si alguna
  variable tiene menos de 10 días válidos, la app dice cuántos días hay y cuántos faltan.
- **Síntomas visibles** (ubre hinchada o caliente, leche anormal, dolor, decaimiento): el modelo no los
  usa, pero si hay alguno marcado hoy la recomendación pide consultar al veterinario aunque el
  semáforo no esté en rojo.
- **Interfaz de campo**: texto base de 18 px, botones de al menos 64 px de alto, alto contraste, ícono y
  texto en cada acción, coma decimal aceptada. El amarillo del semáforo lleva texto oscuro.
- **Diseño adaptable**: en celular, una columna; desde 700 px de ancho (tableta), cuadrícula de 2 o 3
  columnas, ficha y resultado en dos paneles y gráficas lado a lado.
- **Animaciones**: entrada escalonada de las tarjetas, semáforo que se enciende, barra de probabilidad
  que se llena, transición entre login y app. Se desactivan si el sistema pide reducir el movimiento.
- **Navegación**: las pantallas de la sesión viven en un navegador propio dentro de la sesión; al
  cerrar sesión se cierra todo junto con la base.

## Librerías (dentro del stack definido)

| Librería | Uso |
|---|---|
| flutter_bloc + equatable | Estado (cubits). |
| drift + sqlite3 (`source: sqlcipher`) | Base local cifrada. `sqlcipher_flutter_libs` está descontinuado; ahora el paquete `sqlite3` descarga el binario de SQLCipher verificado por sha256. |
| flutter_secure_storage | Tokens y claves de la base. |
| flutter_litert | Intérprete TFLite (API compatible con tflite_flutter). |
| fl_chart | Gráficas del historial. |
| dio | Cliente HTTP con renovación de sesión. |
| uuid | Ids generados en el celular para trabajar sin conexión. |
| intl + flutter_localizations | Fechas y textos del sistema en español. |

`bloc_test` se dejó fuera porque es incompatible con la versión de `build_runner` que exige Drift;
los cubits se prueban con `flutter_test` sobre una base Drift en memoria.
