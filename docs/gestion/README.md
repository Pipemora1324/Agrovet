# Gestión del proyecto AgroVet

AgroVet es una app Android sin conexión para la alerta temprana de mastitis bovina en pequeñas
fincas de Nariño. Es el trabajo de grado de Juan Felipe Mora (Ingeniería de Software, UCC Pasto).
Esta carpeta reúne cómo se gestiona el proyecto en GitHub: backlog, sprints, cronograma, seguimiento
y evidencias de pruebas.

**Tablero:** AgroVet – Gestión del proyecto (GitHub Project). Al 2026-11-10 **está pendiente de crear**: la CLI necesita el permiso `project` del autor. Se publicará en los [Projects de Pipemora1324](https://github.com/Pipemora1324?tab=projects) y este enlace se actualizará.

## Criterio de evaluación → dónde verlo

| Criterio | Dónde verlo |
|---|---|
| Implementación coherente y profesional en GitHub | [Project](https://github.com/Pipemora1324?tab=projects) con 5 vistas; [plantillas de issues](../../.github/ISSUE_TEMPLATE) y [de PR](../../.github/pull_request_template.md); etiquetas por tipo, área, prioridad y estado; flujo `feature → develop → main` con `--no-ff` ([CONTRIBUTING](../CONTRIBUTING.md)) |
| Backlog priorizado y trazable a los requerimientos | [backlog.md](backlog.md); vista «Backlog» del Project (por épica y prioridad); [issues](https://github.com/Pipemora1324/Agrovet/issues); cada issue enlaza su RF/RNF/HU de [REQUISITOS.md](../REQUISITOS.md) |
| Tareas y sprints organizados con avance visible | [Milestones](https://github.com/Pipemora1324/Agrovet/milestones?state=all) (un sprint cada uno, con su % de avance); sub-issues en cada épica; vista «Sprint actual» del Project |
| Fechas y cronograma con control | [sprints.md](sprints.md) con fechas, objetivo, resultado y revisión; vista «Cronograma» del Project (fecha de inicio y objetivo); [gráfica de velocidad](velocidad.png) |
| Evidencias de pruebas completas y organizadas | [pruebas/](pruebas/README.md): corridas del CI en verde, [trazabilidad](pruebas/trazabilidad.md), [informe del emulador](pruebas/emulador.md) con capturas, [calidad de datos](pruebas/calidad_datos.md); issues de tipo prueba #80–#85 |
| Acceso y presentación clara | Este índice, enlazado desde el [README principal](../../README.md); repositorio y Project con enlace directo |

## Metodología

Es un **Scrum adaptado a un equipo de una persona**, con flujo **Kanban** en el tablero y
**CRISP-DM** para la parte de datos y modelos.

- **Scrum adaptado.** Hay sprints de dos semanas con objetivo, backlog comprometido, revisión y
  retrospectiva escritas ([sprints.md](sprints.md)). El autor cumple los roles de product owner y de
  equipo de desarrollo. La validación con usuarios (ganaderos y un veterinario) está planificada
  para el sprint 4. No hay reuniones diarias: el seguimiento queda en los issues, los commits y el CI.
- **Kanban.** El campo Estado del Project tiene las columnas Backlog → Listo → En progreso →
  En revisión → Hecho. Un issue llega a Hecho solo cuando se cierra con evidencia: commit, prueba y,
  si aplica, captura.
- **CRISP-DM** para `ml/`:
  1. *Comprensión del negocio y de los datos:* revisión de datasets públicos.
  2. *Preparación:* dataset sintético, recorte y agrupación por vaca.
  3. *Modelado:* LSTM y CNN.
  4. *Evaluación:* partición por vaca, validación cruzada agrupada, intervalos de confianza y
     experimento de sesgo.
  5. *Despliegue:* TFLite con vectores de prueba en la app.

  Los resultados y sus límites están en [pruebas/calidad_datos.md](pruebas/calidad_datos.md).
- **Definición de terminado:**
  - criterios de aceptación cumplidos;
  - pruebas automáticas del módulo en verde en el CI;
  - documentación al día;
  - commit en español a nombre del autor, integrado a `develop` con `--no-ff`.

  Desde el sprint 3, cada cambio entra además por un pull request con la
  [plantilla](../../.github/pull_request_template.md).

## Contenido

| Documento | Qué contiene |
|---|---|
| [backlog.md](backlog.md) | Estructura épica → HU → requisito → tarea, etiquetas, conteos por épica, tipo y prioridad |
| [sprints.md](sprints.md) | Los 5 sprints con fechas, objetivo, resultado real, revisión y retrospectiva; velocidad |
| [velocidad.png](velocidad.png) | Puntos e issues por sprint, generados desde los issues |
| [pruebas/README.md](pruebas/README.md) | Corridas del CI de v0.1.0 (backend 104, mobile 188, ml 80) y cómo reproducirlas |
| [pruebas/trazabilidad.md](pruebas/trazabilidad.md) | Requisito → HU → issue → commit → prueba → resultado |
| [pruebas/emulador.md](pruebas/emulador.md) | 13 pruebas reales en teléfono y tableta, 10 problemas corregidos, capturas |
| [pruebas/calidad_datos.md](pruebas/calidad_datos.md) | Datos sintéticos, datasets públicos, CNN y sus límites |
| [../REQUISITOS.md](../REQUISITOS.md) | RF-01..18, RNF-01..08 y HU-01..09 con su estado |

## GitHub Project

[AgroVet – Gestión del proyecto](https://github.com/Pipemora1324?tab=projects), enlazado al repositorio.

| Campo | Valores |
|---|---|
| Estado | Backlog, Listo, En progreso, En revisión, Hecho |
| Prioridad | Must, Should, Could, Won't |
| Estimación | puntos de historia (1, 2, 3, 5, 8, 13) |
| Sprint | iteraciones de 2 semanas: Sprint 1 a Sprint 5 |
| Fecha de inicio / Fecha objetivo | fechas reales del commit o fechas planificadas |
| Área | ml, backend, mobile, infra, docs |
| Requisito | RF / RNF / HU que cubre |
| Épica y Tipo | para agrupar y filtrar |

Vistas:
1. **Backlog:** tabla agrupada por épica y ordenada por prioridad.
2. **Sprint actual:** kanban por Estado, filtrado al sprint en curso.
3. **Cronograma:** roadmap por fecha de inicio y fecha objetivo.
4. **Por área.**
5. **Hecho / entregado.**

## Notas de transparencia

- Hasta v0.1.0 no hubo pull requests: las ramas se integraban con merge local `--no-ff` (se ve en el
  historial). El primer pull request es el de esta gestión, en el sprint 3.
- Varios issues se registraron a posteriori el 2026-11-10 (etiqueta `registro-retroactivo`). Sus
  fechas y su sprint salen de los commits citados en cada uno, y las estimaciones también se
  asignaron a posteriori.
- Las métricas del LSTM salen de un dataset sintético y **no validan** la hipótesis F1 ≥ 0,80.
- Lo planificado (sprints 4 y 5) está marcado como tal, con fechas propuestas.
