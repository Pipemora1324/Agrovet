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
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080   # emulador con el backend local
```

La dirección del servidor sale **solo** de `--dart-define=API_BASE_URL`; sin ella la app muestra
"Configuración incompleta". En debug se acepta HTTP solo hacia `10.0.2.2`, `localhost` y
`127.0.0.1`; en release, solo HTTPS (`lib/core/config.dart` y `network_security_config.xml`).

En la pantalla de ingreso de una compilación **debug** aparece el botón
**"Ver con datos de demostración"**: abre una sesión local con 6 vacas inventadas (prefijo `DEMO`)
y un rótulo amarillo "Datos de demostración" en todas las pantallas. Esos datos viven en una base
aparte, nunca se sincronizan y el botón no existe en las compilaciones release.

Para ingresar con una cuenta real, el backend debe estar corriendo (`backend/`, `docker compose up`).
Desde el emulador el equipo es `10.0.2.2`. Para un servidor publicado:

```bash
flutter run --dart-define=API_BASE_URL=https://mi-servidor.example.org
```

En un celular conectado por USB, la forma más simple es redirigir los puertos del equipo
(`localhost` está permitido en debug):

```bash
adb reverse tcp:8080 tcp:8080   # backend
adb reverse tcp:8025 tcp:8025   # Mailpit, para leer los códigos en el navegador del celular
flutter run -d <dispositivo> --dart-define=API_BASE_URL=http://localhost:8080
```

## Registro diario y semáforo

- **Registro de hoy** es un asistente con una pregunta por pantalla: cómo comió, cuánta leche dio
  (solo vacas en ordeño), cómo se siente el cuerpo al tocarla y cómo se ven la ubre y la leche. Al
  tocar una opción pasa sola a la siguiente; todas tienen "No sé", y hay "Atrás", "Empezar de nuevo"
  y "Saltar por hoy".
- Con las respuestas la app **estima** temperatura, leche y alimento respecto a la línea base de la
  vaca (promedio de sus mediciones exactas). El bloque opcional "Tengo termómetro o litros exactos"
  reemplaza lo estimado por lo medido. Cada valor se guarda como `measured` o `estimated` y el
  historial lo muestra. Las equivalencias están en `lib/domain/record_estimates.dart` y son
  provisionales, pendientes de validar con un veterinario (`docs/symptom_score.md`).
- El semáforo final es el más grave entre el **puntaje por síntomas** del día (reglas provisionales,
  a validar con un veterinario: ver `docs/symptom_score.md`) y el **modelo LSTM**. La pantalla dice
  cuál lo indicó. Si no hay días suficientes con mediciones, muestra "Faltan datos para el modelo" y
  se apoya en los síntomas.

## Fotos

- En la ficha de la vaca, **"Fotos"** permite tomar una con la cámara o elegirla de la galería. Se usan
  la cámara y el selector de fotos del sistema, así que AgroVet no pide permiso para leer todas las
  fotos del celular; si la persona negó el acceso a la cámara, la app explica cómo activarlo.
- Cada foto se reduce (lado mayor de 1600 px, JPEG al 80 %), se le quitan los metadatos EXIF/XMP
  (incluida la ubicación GPS) y se guarda en el almacenamiento privado de la app, vinculada a la vaca y
  al día. El historial muestra la galería del periodo.
- Los datos de la foto viajan con la sincronización y luego se sube el archivo (multipart, con
  reintentos). El servidor vuelve a validar el tipo real, el tamaño y quita los metadatos.
- Cada foto tiene, opcionalmente, la confirmación del veterinario, el diagnóstico y el interruptor
  "Permitir usar esta foto para investigación", apagado por defecto (ver `ml/README.md`).
- La CNN de la ubre (`assets/model/udder_cnn.tflite`, entrenada con un dataset público) viene
  **apagada**. Solo se enciende compilando con `--dart-define=UDDER_TRIAGE=true`, y entonces la ficha
  de la foto muestra una lectura con el aviso "Resultado orientativo, no es diagnóstico". No se
  recomienda encenderla (ver `ml/README.md`). Apagada, `android/app/build.gradle.kts` deja el
  `.tflite` fuera del APK (x86_64: 13,98 MiB apagada, 14,82 MiB encendida; el límite es 15 MiB).

## Asistente

- La pestaña **Asistente** de la barra inferior (o **"Preguntar al asistente"** en la ficha) abre un
  chat sobre una vaca. La app envía la
  pregunta, el último semáforo y los síntomas de hoy, los últimos mensajes y, si se adjunta, una foto
  sin metadatos. La clave del proveedor de IA nunca está en la app.
- Aviso fijo en la pantalla: "Orientación de un asistente de IA, no es un diagnóstico".
- La conversación se guarda solo en el celular (base cifrada); no se sincroniza.
- Sin internet aparece un banner y consejos fijos: aislar a la vaca, higiene del ordeño y cuándo
  llamar al veterinario (`lib/domain/assistant_tips.dart`).

## Cuenta

- **Registro**: nombre, correo, contraseña y la casilla obligatoria de autorización de datos
  (Ley 1581 de 2012), con enlace al aviso de privacidad completo. El servidor guarda la versión del
  aviso aceptada y la fecha.
- **Verificación del correo**: después del registro llega un código de 6 números (en desarrollo, a
  Mailpit: `http://localhost:8025`). La pantalla del código lo verifica apenas se escriben los 6
  números y permite reenviarlo con una cuenta regresiva de 60 s, que se ajusta al `Retry-After` del
  servidor. Si alguien intenta ingresar sin haber verificado, la app lo lleva a esa pantalla.
- **Olvidé mi contraseña**: código al correo, contraseña nueva y la app inicia sesión sola.
- **Internet**: registro, verificación, recuperación y cambios del perfil necesitan conexión. Una vez
  abierta, la sesión queda guardada y la app funciona sin internet.
- **Perfil** (pestaña de la barra inferior):
  - ver y editar nombre, finca, municipio y teléfono opcional (se guarda una copia para verlo sin
    conexión);
  - cambiar la contraseña, lo que cierra la sesión en los demás celulares;
  - leer el aviso de privacidad (las cuentas creadas antes del aviso deben aceptarlo aquí);
  - cerrar sesión;
  - **eliminar la cuenta**: pide la contraseña, borra todo en el servidor y luego, en el celular, la
    base cifrada y sus claves.

El texto del aviso está en `lib/domain/privacy_notice.dart`. Si cambia de forma sustancial, hay que
subir su versión para que la app lo pida de nuevo.

### APK para instalar

```bash
flutter build apk --release --split-per-abi --dart-define=API_BASE_URL=https://api.su-dominio.co
```

(Pasos del servidor en `docs/DEPLOY.md`.)

Genera un APK por arquitectura en `build/app/outputs/flutter-apk/`. La mayoría de los celulares
actuales usa `arm64-v8a`; los más viejos o de gama muy baja, `armeabi-v7a`.

| APK | Tamaño |
|---|---|
| arm64-v8a | 12,5 MB |
| armeabi-v7a | 11,6 MB |
| x86_64 (emuladores) | 13,5 MB |

Antes un solo APK arm64 pesaba 39,1 MB. Para bajarlo:
- se quitaron el delegado de GPU de TFLite y el runtime de LiteRT de la API CompiledModel, que
  `flutter_litert` incluye pero la app no usa (solo usa el intérprete en CPU);
- las bibliotecas nativas van comprimidas dentro del APK.

El CI falla si algún APK pasa de 15 MB.

En release solo se permite HTTPS: el permiso para HTTP sin cifrar existe únicamente en debug y
solo hacia `10.0.2.2`, `localhost` y `127.0.0.1`.

## Pruebas

```bash
flutter analyze
flutter test
# En el emulador o un celular conectado:
flutter test integration_test/test_vectors_on_device_test.dart -d <dispositivo> \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080
# Recorrido completo (demo, cuenta real con verificación, perfil y eliminación). Necesita el backend
# y Mailpit del docker-compose; en un celular por USB, con adb reverse de 8080 y 8025:
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_flow_test.dart \
  -d <dispositivo> --keep-app-running --dart-define=API_BASE_URL=http://10.0.2.2:8080
#   celular por USB, en lugar de las anteriores: --dart-define=API_BASE_URL=http://localhost:8080 --dart-define=MAILPIT_URL=http://localhost:8025
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
  domain/        entidades, preprocesamiento (réplica de Python), semáforo, recomendaciones, aviso de privacidad
  data/          base local (Drift + SQLCipher), almacenamiento seguro, API, modelo TFLite, demo
  presentation/  pantallas y cubits (cuenta, perfil, vacas, registro diario, riesgo, historial, respaldo)
```

**Tema**: colores, tipografía, radios y estilos de botones viven solo en `lib/core/theme.dart`
(`AppColors`, `AppTextStyles`, `AppRadius`, `AppButtonStyles` y el `ThemeData` de Material 3). Las
pantallas usan esos nombres y los roles de Material. La prueba `test/architecture_test.dart` falla si
algún archivo fuera del tema escribe un color o un tamaño de letra, para que el rediseño se haga
cambiando un solo archivo.

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
- Al eliminar la cuenta, primero se borra en el servidor; luego se cierra la base, se borran su
  archivo (y los auxiliares `-wal`/`-shm`) y se olvidan su clave y la fecha de la última
  sincronización.

## Sincronización

Todo se guarda primero en el celular; cada cambio queda marcado como pendiente.

- **Cuándo**: al abrir la sesión, al volver la app al frente y al recuperar la conexión
  (`connectivity_plus`) si hay cambios pendientes; cuando el ganadero toca "Sincronizar ahora"; y cada
  15 minutos en segundo plano con `workmanager`, aunque la app esté cerrada (solo con red; si falla,
  Android reintenta con espera exponencial). Android decide el momento exacto de la tarea periódica y
  puede atrasarla para agruparla con otras.
- **Cómo**: `POST /api/sync` en lotes de hasta 200 elementos por tipo, primero las vacas. Ante fallas
  de red o del servidor se reintenta con espera exponencial (2, 4 y 8 s, con variación).
- **Confirmación**: solo se marca como sincronizado lo que el servidor confirma, y solo si la fila no
  cambió mientras se enviaba. Nunca se borra nada local.
- **Rechazos**: si el servidor rechaza un elemento (por ejemplo, otro registro para el mismo día), se
  guarda el motivo y no se reintenta hasta que el ganadero lo corrija.
- **Estado**: la nube de la barra superior muestra cuántos cambios faltan por subir y cambia de ícono
  si hay un problema. Al tocarla se abre "Respaldo de datos" con los pendientes, la hora de la última
  sincronización (la guardan tanto la app como la tarea en segundo plano), el error del último intento,
  lo que el servidor rechazó con su motivo y el botón **"Sincronizar ahora"**. Solo cuenta como
  sincronización un envío que el servidor confirmó.
- La sesión de demostración no sincroniza.

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
- **Alertas**: cada evaluación amarilla o roja crea una alerta. Las que siguen sin atender aparecen en
  la ficha de la vaca con el botón "Marcar como atendida"; al tocarlo se guarda la fecha y el cambio
  se sincroniza como cualquier otro. Si llega tarde una versión vieja, el servidor no deshace la
  atención.
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
