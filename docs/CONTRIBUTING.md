# Guía de contribución

## Ramas

| Rama                       | Uso                                                        |
|----------------------------|------------------------------------------------------------|
| `main`                     | Versión estable. Solo recibe merges desde `develop`.       |
| `develop`                  | Integración. Aquí llegan las ramas de funcionalidad.       |
| `feature/<modulo>-<tema>`  | Trabajo puntual. Ej.: `feature/ml-dataset`, `feature/backend-sync`. |

Módulos: `ml`, `backend`, `mobile`, `docs`, `repo`.

Reglas:

- Nunca se hace commit directo en `main`.
- Cada rama de funcionalidad sale de `develop` y vuelve a `develop` con merge `--no-ff`,
  para que quede visible en el historial qué entró junto.
- Cuando una fase está terminada y probada, `develop` se integra a `main` también con `--no-ff`.

```bash
git checkout develop
git pull
git checkout -b feature/backend-sync
# ... commits ...
git checkout develop
git merge --no-ff feature/backend-sync
git push origin develop feature/backend-sync
```

## Commits

- En español, cortos y en presente: qué cambia, no cómo.
- Un commit por cambio lógico; mejor varios pequeños que uno grande.
- Si hace falta explicar el porqué, se deja una línea en blanco y se agrega un párrafo corto.

Ejemplos:

```
agrega generador del dataset sintético
corrige validación de fechas en registros diarios
ajusta tamaño de los botones en la captura diaria
```

Evitar mensajes como `cambios`, `arreglos` o `wip`.

## Pull requests

- Título corto en español, igual de claro que un buen commit.
- Llenar la plantilla: qué cambia, cómo se probó y qué falta.
- El CI del módulo debe pasar antes de integrar.

## Issues

- Requerimientos con la plantilla **Requerimiento** (RF / RNF) y fallos con la plantilla **Bug**.
- Etiquetas por módulo (`ml`, `backend`, `mobile`, `docs`) y por prioridad (`prioridad:alta`, `prioridad:media`, `prioridad:baja`).

## Estilo de código

- **Python**: PEP 8, revisado con `flake8`.
- **Java**: convenciones de Spring; controller → service → repository; DTOs separados de entidades.
- **Dart**: `flutter analyze` sin advertencias; arquitectura por capas (presentation, domain, data).
