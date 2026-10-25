#!/usr/bin/env bash
# Crea las etiquetas y los issues de requerimientos de AgroVet en GitHub.
#
# Requisitos: GitHub CLI autenticado (gh auth login) y ejecutar desde la raíz del repo.
# Se puede correr varias veces: las etiquetas se actualizan y los issues que ya
# existen (mismo código RF/RNF en el título) se saltan.
#
# Uso:  bash scripts/create_issues.sh            # crea todo
#       bash scripts/create_issues.sh --dry-run  # solo muestra lo que haría

set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

if ! $DRY_RUN; then
  command -v gh >/dev/null || { echo "Falta GitHub CLI (gh)."; exit 1; }
  gh auth status >/dev/null 2>&1 || { echo "Primero: gh auth login"; exit 1; }
fi

label() {  # nombre color descripción
  if $DRY_RUN; then
    echo "[etiqueta] $1"
  else
    gh label create "$1" --color "$2" --description "$3" --force >/dev/null
    echo "Etiqueta lista: $1"
  fi
}

issue() {  # código título etiquetas cuerpo
  local code="$1" title="$2" labels="$3" body="$4"
  if $DRY_RUN; then
    echo "[issue] $code: $title  ($labels)"
    return
  fi
  local existing
  existing=$(gh issue list --state all --search "\"$code:\" in:title" --json title --jq '.[].title')
  if grep -q "^$code:" <<<"$existing"; then
    echo "Ya existe: $code"
    return
  fi
  gh issue create --title "$code: $title" --label "$labels" --body "$body" >/dev/null
  echo "Creado: $code"
}

# --- Etiquetas ---
label "requerimiento"   "0E8A16" "Requerimiento funcional o no funcional"
label "no-funcional"    "5319E7" "Requerimiento no funcional"
label "bug"             "D73A4A" "Algo no funciona"
label "ml"              "1D76DB" "Modelo y datos (Python)"
label "backend"         "B60205" "API Spring Boot"
label "mobile"          "FBCA04" "App Android (Flutter)"
label "docs"            "C5DEF5" "Documentación"
label "prioridad:alta"  "B60205" "Necesario para la entrega"
label "prioridad:media" "D93F0B" "Importante, no bloqueante"
label "prioridad:baja"  "0E8A16" "Deseable"

# --- Requerimientos funcionales ---
issue "RF-01" "Registro e inicio de sesión" "requerimiento,backend,mobile,prioridad:alta" \
"Como ganadero, quiero crear una cuenta e iniciar sesión para que mis datos queden asociados a mí.

- [ ] Registro con nombre, correo y contraseña (guardada con BCrypt)
- [ ] Login que devuelve un token de acceso de vida corta y un refresh token
- [ ] Renovación de sesión con rotación del refresh token
- [ ] La app guarda la sesión y funciona offline después del primer ingreso"

issue "RF-02" "Registro y edición de bovinos" "requerimiento,backend,mobile,prioridad:alta" \
"Como ganadero, quiero registrar mis vacas para llevar su seguimiento.

- [ ] Campos: identificador, raza, edad, número de partos, estado productivo
- [ ] Crear, editar, listar y dar de baja
- [ ] Funciona sin conexión; el ID (UUID) se genera en el celular"

issue "RF-03" "Captura diaria con validación de rangos" "requerimiento,mobile,prioridad:alta" \
"Como ganadero, quiero registrar cada día temperatura, leche y alimento de cada vaca.

- [ ] Temperatura (°C), leche (L) y alimento (kg) con rangos válidos
- [ ] Checklist de síntomas visibles (ubre inflamada, leche con grumos, dolor al ordeño, etc.)
- [ ] Mensajes claros cuando un valor está fuera de rango
- [ ] Un registro por vaca y día (editar si ya existe)"

issue "RF-04" "Historial por bovino con gráficas" "requerimiento,backend,mobile,prioridad:media" \
"Como ganadero, quiero ver la evolución de cada vaca para notar cambios.

- [ ] Gráficas de temperatura, leche y alimento por fecha
- [ ] Historial de resultados del semáforo
- [ ] Endpoint de historial por bovino en el backend"

issue "RF-05" "Inferencia LSTM offline" "requerimiento,mobile,ml,prioridad:alta" \
"Como ganadero, quiero saber el riesgo de mastitis sin depender de internet.

- [ ] Ventana de los últimos 14 días -> probabilidad de síntomas clínicos en 1 a 5 días
- [ ] Modelo TFLite dentro de la app
- [ ] Aviso si faltan días de registro para calcular"

issue "RF-06" "Semáforo de riesgo con recomendación" "requerimiento,mobile,prioridad:alta" \
"Como ganadero, quiero un resultado fácil de entender.

- [ ] Verde (sano), amarillo (alerta temprana), rojo (alto riesgo)
- [ ] Recomendación básica según el color
- [ ] Aviso visible: la herramienta apoya, no reemplaza al veterinario"

issue "RF-07" "Registro de inferencias y alertas" "requerimiento,backend,mobile,prioridad:media" \
"Como ganadero, quiero que quede guardado cada resultado y cada alerta.

- [ ] Guardar probabilidad, color, versión del modelo y fecha
- [ ] Generar alerta en amarillo o rojo
- [ ] Marcar alertas como atendidas"

issue "RF-08" "Sincronización por lotes idempotente" "requerimiento,backend,prioridad:alta" \
"Como sistema, necesito recibir los datos del celular sin duplicarlos.

- [ ] Endpoint que recibe lotes de bovinos, registros, inferencias y alertas
- [ ] Upsert por UUID: reenviar el mismo lote no crea duplicados
- [ ] Respuesta con los IDs confirmados"

issue "RF-09" "Sincronización en segundo plano" "requerimiento,mobile,prioridad:media" \
"Como ganadero, quiero que mis datos se respalden solos cuando haya señal.

- [ ] Tarea en segundo plano (workmanager) al haber conexión
- [ ] Reintentos con espera creciente ante fallos
- [ ] Los datos locales se conservan hasta que el servidor confirma"

issue "RF-10" "Triaje visual de la ubre con foto" "requerimiento,ml,mobile,prioridad:baja" \
"Como ganadero, quiero tomar una foto de la ubre para una revisión preliminar.

- [ ] Modelo CNN MobileNetV2 con transfer learning
- [ ] Captura de foto desde la app
- [ ] Queda pendiente hasta contar con imágenes reales etiquetadas"

issue "RF-11" "Dataset sintético de entrenamiento" "requerimiento,ml,prioridad:alta" \
"Como desarrollador, necesito datos para construir y probar el pipeline mientras llegan datos reales.

- [ ] 600 vacas, 60 días, 35 % enferman, semilla fija
- [ ] Línea base por vaca, celo, estrés calórico y registros erróneos
- [ ] Fase subclínica de 5 a 7 días antes del inicio clínico"

issue "RF-12" "Entrenamiento y evaluación del LSTM" "requerimiento,ml,prioridad:alta" \
"- [ ] Ventanas de 14 días con normalización por ventana
- [ ] Partición por vaca 70/15/15 estratificada
- [ ] Umbral por F1 en validación
- [ ] Métricas en test: F1, precisión, sensibilidad, AUC, matriz de confusión, anticipación y falsas alarmas"

issue "RF-13" "Exportación a TFLite y vectores de prueba" "requerimiento,ml,mobile,prioridad:alta" \
"- [ ] Modelo .tflite con entrada [1,14,3] equivalente al de Keras
- [ ] model_config.json con ventana, escalas, umbral y rangos del semáforo
- [ ] test_vectors.json con 8 casos para verificar la app"

# --- Requerimientos no funcionales ---
issue "RNF-01" "Funcionamiento sin conexión" "requerimiento,no-funcional,mobile,prioridad:alta" \
"- [ ] Registro, consulta e inferencia funcionan sin internet
- [ ] La sincronización es transparente para el usuario"

issue "RNF-02" "Interfaz apta para trabajo de campo" "requerimiento,no-funcional,mobile,prioridad:alta" \
"- [ ] Botones grandes y alto contraste (legible a pleno sol)
- [ ] Poco texto, íconos claros
- [ ] Diseño adaptable a celulares y tablets
- [ ] Probado en un celular de gama baja"

issue "RNF-03" "Seguridad de la API" "requerimiento,no-funcional,backend,prioridad:alta" \
"- [ ] Token de acceso de vida corta y refresh token con rotación
- [ ] Contraseñas con BCrypt
- [ ] Límite de intentos en el login
- [ ] CORS restringido a orígenes configurados
- [ ] Validación de toda entrada (Bean Validation)
- [ ] Solo consultas parametrizadas
- [ ] Cada usuario solo accede a sus propios datos, con pruebas que lo demuestren
- [ ] Secretos y URL de la base solo por variables de entorno"

issue "RNF-08" "Protección de los datos en el celular" "requerimiento,no-funcional,mobile,prioridad:alta" \
"- [ ] Base local cifrada (SQLCipher)
- [ ] Tokens en almacenamiento seguro del sistema
- [ ] La clave de la base no queda en el código"

issue "RNF-04" "Paridad del preprocesamiento Python / Dart" "requerimiento,no-funcional,ml,mobile,prioridad:alta" \
"- [ ] La app reproduce test_vectors.json con tolerancia 1e-4
- [ ] La prueba corre en el CI de la app"

issue "RNF-05" "Compatibilidad Android" "requerimiento,no-funcional,mobile,prioridad:media" \
"- [ ] minSdk 24 (Android 7.0) o superior
- [ ] Tamaño de APK razonable para planes de datos limitados"

issue "RNF-06" "Integración continua por módulo" "requerimiento,no-funcional,docs,prioridad:media" \
"- [ ] Un workflow por módulo (ml, backend, mobile)
- [ ] Las pruebas deben pasar antes de integrar a develop
- [ ] Dependabot y revisión de dependencias en los pull requests
- [ ] Actions fijadas por SHA"

issue "RNF-07" "Documentación de la API" "requerimiento,no-funcional,backend,docs,prioridad:baja" \
"- [ ] Swagger / OpenAPI disponible en el backend
- [ ] README de cada módulo con instrucciones de ejecución"

echo "Listo."
