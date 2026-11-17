# Servidor de demostración en Render (plan gratuito)

> **Estado: listo para desplegar, no desplegado.**
> - Los archivos están en el repositorio:
>   - [`render.yaml`](../render.yaml);
>   - [`backend/deploy/render/`](../backend/deploy/render/);
>   - [`mobile/tool/build_demo_apk.ps1`](../mobile/tool/build_demo_apk.ps1).
> - Nada se ha ejecutado en Render. Las cifras salen de una prueba local que imita el plan gratuito
>   (Docker con `--memory=512m --cpus=0.1`, 2026-11-17) con las mismas variables del `render.yaml`.
> - Render puede comportarse distinto: hay que medir de nuevo después del primer despliegue.

Objetivo: un servidor **de demostración** para que la app funcione con cuenta real (ingreso, datos
desde la base, asistente con Gemini, fotos y sincronización) mientras no haya un servidor propio (ver
[DEPLOY.md](DEPLOY.md) para el servidor definitivo). Los datos son sintéticos.

## Resumen

| Pregunta | Respuesta |
|---|---|
| ¿Cabe en 512 MB? | Sí. La API usó 218–247 MiB en la prueba local, con 512 MB de límite. |
| ¿Funciona el ingreso con la cuenta de demostración? | Sí. El usuario se crea ya verificado con `seed_demo.ps1`. |
| ¿Funciona el registro de cuentas nuevas? | **Solo a medias.** El plan gratuito bloquea el SMTP (puertos 25, 465 y 587): el código de verificación nunca llega. Cada cuenta nueva se verifica a mano con `verify_account.ps1`. |
| ¿Funcionan las vacas, el historial, la sincronización y las fotos? | Sí (probado en local contra la misma imagen y las mismas variables). Las fotos se borran cuando el servicio se duerme. |
| ¿Funciona el asistente? | Sí, si se define `GEMINI_API_KEY`. La salida a Gemini es HTTPS (puerto 443), que no está bloqueado. Sin clave responde 503 y la app muestra consejos fijos. |
| Arranque en frío | **En la prueba local con 0,1 de CPU, la API tardó 147–168 s en arrancar** (197 s sin los ajustes de la JVM). Hay que despertarla unos 3 minutos antes de una demostración. |
| ¿Se pierde algo? | Las **fotos** (no hay disco persistente) y, a los 30 días, **la base de datos** completa. |

## Límites del plan gratuito que importan aquí

Fuentes, leídas el 2026-11-17:
- [render.com/docs/free](https://render.com/docs/free);
- [render.com/docs/compute-plans](https://render.com/docs/compute-plans);
- [render.com/docs/blueprint-spec](https://render.com/docs/blueprint-spec);
- [render.com/docs/health-checks](https://render.com/docs/health-checks).

Límites:
- Servicio web: **512 MB y 0,1 CPU**. Se duerme tras **15 minutos** sin tráfico entrante; al
  despertar se pierde lo escrito en su disco local. 750 horas gratis al mes por espacio de trabajo.
- "Free web services can't send outbound network traffic on ports `25`, `465`, or `587`, commonly
  used for SMTP."
- Sin disco persistente, sin Shell/SSH y sin tareas puntuales (*one-off jobs*).
- Postgres gratuito: 1 GB, 0,1 CPU y 256 MB. **Vence a los 30 días de creado**; luego hay 14 días
  para pasarlo a un plan pago y después se borra con todos sus datos. Sin copias de seguridad. Una
  base gratuita por espacio de trabajo.
- Un despliegue nuevo tiene **15 minutos** para pasar el chequeo de salud; si no, Render lo cancela.
  Cada chequeo debe responder en 5 s. El arranque medido (≈2,5–3 min) cabe con margen.

## Qué hay en el repositorio

| Archivo | Para qué |
|---|---|
| [`render.yaml`](../render.yaml) | Blueprint: crea la base `agrovet-db` y el servicio `agrovet-api` (Docker, plan gratuito, región Virginia), con todas las variables. Sin secretos. |
| `backend/Dockerfile` | Sin cambios: compila con el JDK 21 y corre con el JRE 21, con un usuario sin privilegios. |
| `DatabaseUrlEnvironmentPostProcessor` (backend) | Si no hay `DB_URL` pero sí `DATABASE_URL` (formato de Render, `postgresql://usuario:clave@host:puerto/base`), arma la dirección JDBC y toma de ahí el usuario y la clave. Así Render enlaza la base sola. Con `DB_URL` definida (docker-compose, VPS) no cambia nada. |
| [`backend/deploy/render/seed_demo.ps1`](../backend/deploy/render/seed_demo.ps1) + `seed_demo.sql` | Crea el usuario de demostración (verificado) y sus 6 vacas sintéticas. |
| [`backend/deploy/render/verify_account.ps1`](../backend/deploy/render/verify_account.ps1) + `verify_account.sql` | Marca como verificado el correo de una cuenta nueva. |
| [`mobile/tool/build_demo_apk.ps1`](../mobile/tool/build_demo_apk.ps1) | Compila el APK que apunta al servidor, con la demostración local como respaldo. |

## Variables de entorno

Todas están en `render.yaml`; ninguna lleva un secreto escrito.

| Variable | Valor | De dónde sale |
|---|---|---|
| `SPRING_PROFILES_ACTIVE` | `prod` | `render.yaml` |
| `PORT` | `8080` (el puerto de Spring; Render enruta ahí) | `render.yaml` |
| `JAVA_TOOL_OPTIONS` | `-XX:MaxRAMPercentage=70 -XX:+UseSerialGC -XX:TieredStopAtLevel=1 -Xss512k` | `render.yaml` |
| `PHOTO_STORAGE_DIR` | `/app/data/photos` (disco efímero) | `render.yaml` |
| `DATABASE_URL` | Dirección **interna** de `agrovet-db` | Render la enlaza (`fromDatabase`) |
| `JWT_SECRET` | 256 bits al azar en base64 | Render la genera al crear el servicio (`generateValue`) |
| `MAIL_HOST` | `localhost` (no hay servidor: el envío falla al instante, en segundo plano) | `render.yaml` |
| `MAIL_USERNAME` | `sin-correo@agrovet.invalid` (**no es una credencial**) | `render.yaml` |
| `MAIL_PASSWORD` | `no-aplica` (**no es una credencial**) | `render.yaml` |
| `MAIL_FROM` | `AgroVet <sin-correo@agrovet.invalid>` | `render.yaml` |
| `GEMINI_API_KEY` | Su clave de Google AI Studio (**secreto**) | Render la pide al crear el Blueprint (`sync: false`) |

- Las cuatro `MAIL_*` existen solo para que arranque el perfil `prod`, que exige SMTP. **No** ponga la
  clave de Gmail: no serviría (SMTP bloqueado) y quedaría en otro servidor.
- Opcionales, con valor por defecto en `application.yml`:
  - `GEMINI_MODEL` (`gemini-3.1-flash-lite`);
  - `ASSISTANT_MAX_PER_HOUR` (20) y `ASSISTANT_MAX_PER_DAY` (60);
  - `JWT_ACCESS_TTL` (PT15M) y `JWT_REFRESH_TTL` (P14D).

## Medición local (imita el plan gratuito)

Montaje de la prueba:
- Imagen de `backend/Dockerfile`.
- Postgres 15 con `--memory=256m --cpus=0.1`.
- API con `--memory=512m --memory-swap=512m --cpus=0.1` y exactamente las variables de
  `render.yaml`, con `DATABASE_URL` en formato `postgresql://` y sin `DB_URL`.

| Medición (2026-11-17) | Resultado |
|---|---|
| Arranque sin ajustes de la JVM (prueba anterior) | 197 s, 242 MiB |
| Arranque con `JAVA_TOOL_OPTIONS` | 147 s (prueba anterior) y 168 s (esta prueba); 219 MiB |
| Memoria tras ingreso, historial, foto y chat | 247 MiB |
| Primer ingreso (BCrypt costo 12 con 0,1 CPU) | 12,9 s |
| `GET /api/cows` / historial de 30 días / `POST /api/sync` | 0,5 s / 0,9 s / 1,6 s |
| Subir una foto / chat con Gemini | 2,6 s / 7,6 s |

Pruebas hechas con el usuario de demostración:
- **Datos:** `seed_demo.ps1` creó 6 vacas y 126 registros. Ingreso 200, 6 vacas, historial de 30
  registros de Canela, `POST /api/sync` 200.
- **Foto:** subida 204, descarga 200 con el mismo tamaño.
- **Chat:** 200, con respuesta de Gemini.
- **Cuenta nueva:**
  - registro 202, y el correo falló en segundo plano;
  - ingreso 403 `EMAIL_NOT_VERIFIED`;
  - `verify_account.ps1`, y después el ingreso respondió 200.
- **Errores del script:** un correo repetido falla y no cambia nada; una clave de menos de 8
  caracteres se rechaza antes de conectarse.

El tiempo de espera de la app es 10 s para conectar y 30 s por respuesta, así que el ingreso (≈13 s
en frío, ≈5 s en caliente) cabe.

## Correo y registro

El backend exige verificar el correo antes de ingresar, y en Render gratuito el correo no puede salir.
Solución elegida para la demostración (sin cambiar el código):

- Se ingresa con el usuario de demostración que crea `seed_demo.ps1` (ya verificado).
- Si alguien se registra, se verifica a mano desde el PC con `verify_account.ps1`.
- "Olvidé mi contraseña" no funciona, porque también envía un código.

Otras opciones, **no hechas, requieren su decisión**:
- enviar el correo por una API HTTPS (Brevo, Resend), lo que agrega un servicio externo;
- una bandera que apague la verificación, lo que toca la seguridad del registro;
- un plan pago de Render, que permite 465/587 y funcionaría con el Gmail actual.

## APK que apunta al servidor

Desde `mobile/`, con la URL que le dé Render:

```powershell
.\tool\build_demo_apk.ps1 -ApiBaseUrl https://agrovet-api.onrender.com -AlsoWithoutServer
```

El script:
- Rechaza una dirección que no sea HTTPS o que tenga ruta. La app publicada no acepta HTTP.
- Compila arm64 con:
  - `--dart-define=API_BASE_URL=<url>`;
  - `--dart-define=DEMO_MODE=true`;
  - `--dart-define=UDDER_TRIAGE=true`.
- Deja en `mobile/build/demo-apk/`:
  - `agrovet-demo-render-arm64.apk`: ingreso con cuenta real **y** "Entrar a la demostración";
  - con `-AlsoWithoutServer`, también `agrovet-demo-sin-servidor-arm64.apk`: solo la demostración
    local; la app no intenta conectarse y lo dice en el ingreso.
- Muestra tamaño y SHA-256, y falla si un APK pasa de 15 MB (el límite del CI).

**Respaldo sin servidor:** en el APK de Render, "Entrar a la demostración" funciona sin internet ni
servidor (6 vacas en una base aparte que nunca se sincroniza). Si Render está dormido, vencido o
caído, la presentación sigue con la demostración local.

Si el servicio se renombra, la URL cambia y hay que recompilar el APK.

## Arranque en frío: cómo manejarlo

- **Si el servicio está dormido,** el primer ingreso desde la app falla con un mensaje de conexión.
  Tarda ≈3 min en responder: ≈1 min para que Render lo despierte y 2,5–3 min para que arranque Spring
  con 0,1 CPU. La sincronización pendiente se reintenta sola más tarde.
- **Antes de una demostración,** abra en el navegador
  `https://agrovet-api.onrender.com/actuator/health` y espere a ver `{"status":"UP"…}`. Después el
  servicio sigue despierto mientras reciba tráfico cada menos de 15 minutos.
- Mantenerlo despierto con un servicio externo que lo llame cada 14 min cabría en las 750 horas, pero
  agrega otro servicio externo. **No se hizo; requiere su decisión.**

## Pasos para desplegar en su cuenta de Render

1. **Rama:** Render lee `render.yaml` de la rama que elija.
   - Lo normal, según el flujo del proyecto, es `main` después de integrar `develop` en `main`.
   - Mientras tanto puede usar `develop`: el despliegue automático está apagado, así que solo se
     despliega cuando usted lo pide.
2. **Cuenta:** entre a [dashboard.render.com](https://dashboard.render.com); el plan gratuito no pide
   tarjeta. Conecte GitHub dando acceso **solo** al repositorio `Agrovet`.
3. **Blueprint:** *New > Blueprint*, repositorio `Agrovet` y la rama del paso 1. *Blueprint Path*:
   `render.yaml`. Revise que aparezcan:
   - `agrovet-db` (Postgres, Free, Virginia);
   - `agrovet-api` (Web Service, Docker, Free, Virginia).
4. **Clave de Gemini:** Render pide `GEMINI_API_KEY`. Pegue su clave (la de `backend/.env`) o déjela
   vacía para probar sin asistente. *Apply*.
5. **Fechas:** anote la fecha de creación de la base, el vencimiento (+30 días) y el fin del plazo de
   gracia (+14 días).
6. **Primer despliegue:** espere a que termine la compilación de la imagen (varios minutos). En
   *agrovet-api > Logs* busque:
   - `Successfully applied 13 migrations`;
   - `Started AgrovetApplication in … seconds` (anote los segundos, para comparar con los 147–168 s
     locales);
   - `Correo: SMTP localhost:587 con STARTTLS` (es esperado).
7. **Salud:** abra `https://<servicio>.onrender.com/actuator/health`; debe decir `UP`. La URL exacta
   aparece arriba en el panel de `agrovet-api`.
8. **Datos de demostración:** en *agrovet-db > Connections*, copie la **External Database URL**.
   Con Docker Desktop abierto, en PowerShell:

   ```powershell
   cd <repositorio>\backend\deploy\render
   powershell -ExecutionPolicy Bypass -File .\seed_demo.ps1 -Email <correo de demo> -Name "Ganadero demo"
   ```

   - Pegue la URL y escriba dos veces la contraseña que quiera (8 a 72 caracteres). No se ven al
     escribir, no quedan en el historial ni en ningún archivo, y la base solo guarda el hash.
   - Debe terminar con la fila `<correo> | 6 | 126`.
9. **APK:** compílelo con la URL de Render (sección "APK que apunta al servidor") e instálelo en la
   tablet: `adb install -r mobile\build\demo-apk\agrovet-demo-render-arm64.apk`.
10. **Pruebas:** haga las de la lista siguiente.
11. **IP del cliente:** el perfil `prod` toma la IP de `X-Forwarded-For` solo si el proxy tiene una
    dirección interna. Si los avisos de "demasiados intentos" aparecen con poco uso, el límite de 30
    intentos por IP es compartido.
12. **Antes del vencimiento:** pase la base a un plan pago, o acepte que se borre. En ese caso, cree
    otra base gratuita con el Blueprint (*Manual sync*) y vuelva a cargar los datos (paso 8).

Para una cuenta nueva registrada desde la app:

```powershell
powershell -ExecutionPolicy Bypass -File .\verify_account.ps1 -Email <correo de la persona>
```

## Pruebas desde la tablet

Antes de empezar, despierte el servidor (`/actuator/health` en `UP`) y conecte la tablet a internet.

| # | Prueba | Resultado esperado |
|---|---|---|
| 1 | Abrir la app | La pantalla de ingreso muestra el formulario **y** "Entrar a la demostración"; no aparece el aviso de "sin servidor". |
| 2 | Ingresar con el correo y la contraseña del paso 8 | Entra en menos de ~15 s. Si falla por conexión, el servidor estaba dormido: espere y repita. |
| 3 | Lista de vacas (la app las descarga del servidor porque su base local está vacía) | Aparecen 6: DEMO-01 Lucero, DEMO-02 Canela, DEMO-03 Mariposa, DEMO-04 Estrella, DEMO-05 Paloma y DEMO-06 Luna (seca). |
| 4 | Ficha de Canela (DEMO-02) | Historial de 30 días; los últimos 6 muestran subida de temperatura (hasta ≈39,5 °C) y caída de leche. |
| 5 | Ficha de Paloma (DEMO-05) y de Luna (DEMO-06) | Paloma: solo 6 días de registros. Luna: seca y sin registros. |
| 6 | Nuevo registro diario en Lucero y botón de sincronizar (nube) | "Respaldo de datos" queda sin pendientes ni rechazados y con la hora de la última sincronización. |
| 7 | Chat del asistente en Canela: "¿Qué reviso si tiene la temperatura alta?" | Responde en unos segundos con consejos y el aviso de consultar al veterinario. Sin `GEMINI_API_KEY`: mensaje de asistente no disponible y consejos fijos. |
| 8 | Foto de la ubre en Canela (cámara o galería) y sincronizar | La foto queda en la ficha; "Respaldo de datos" queda sin pendientes ni rechazados. En *Logs* de Render no aparecen errores de `PhotoStorage`. |
| 9 | Cerrar sesión, borrar datos de la app (Ajustes de Android > Apps > AgroVet > Almacenamiento) y volver a ingresar | Vuelven las 6 vacas con su historial y el registro del paso 6. **La foto no vuelve:** la app no restaura fotos (limitación conocida) y en Render además se borran al dormirse. |
| 10 | Modo avión y "Entrar a la demostración" | Funciona sin internet, con sus propias 6 vacas de ejemplo. |
| 11 | (Opcional) Crear una cuenta nueva | Pide el código, que no llega. Ejecutar `verify_account.ps1` con ese correo e ingresar: entra. |

Anote en cada prueba si pasó y, si no, el mensaje exacto en pantalla.

## Lo que no cubre

- Correo real (registro y recuperación con código): ver "Correo y registro".
- Fotos persistentes: en esta demostración se pierden cuando el servicio se duerme. Para guardarlas
  haría falta un disco (plan pago) o un almacenamiento de objetos.
- Copias de seguridad: el Postgres gratuito no las tiene.
- No es el servidor definitivo. Ese es el de [DEPLOY.md](DEPLOY.md): VPS con Docker Compose, HTTPS
  con Caddy y SMTP real.
