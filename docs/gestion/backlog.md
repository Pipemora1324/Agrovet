# Backlog del producto

El backlog vive en los [issues del repositorio](https://github.com/Pipemora1324/Agrovet/issues) y en el
[GitHub Project](PROJECT_URL). Este archivo explica cómo está organizado y resume su estado al
2026-11-10.

## Estructura

```
Épica (tipo:epica)
 └─ Historia de usuario HU-01..09 (tipo:historia)
     └─ Requisito RF / RNF (tipo:historia + requerimiento)
         └─ Tarea, bug o prueba
```

La jerarquía está hecha con **sub-issues** de GitHub: cada épica muestra el avance de sus hijos.
Cada issue tiene:
- criterios de aceptación;
- requisito enlazado a [REQUISITOS.md](../REQUISITOS.md);
- estimación en puntos (Fibonacci: 1, 2, 3, 5, 8, 13);
- prioridad MoSCoW;
- sprint y fechas;
- si ya está hecho, los commits que lo resolvieron.

## Etiquetas

| Grupo | Etiquetas |
|---|---|
| Tipo | `tipo:epica`, `tipo:historia`, `tipo:tarea`, `tipo:bug`, `tipo:prueba`, `tipo:documentacion` |
| Área | `backend`, `mobile`, `ml`, `infra`, `docs` |
| Prioridad (MoSCoW) | `prioridad:must`, `prioridad:should`, `prioridad:could`, `prioridad:wont` |
| Estado del requisito | `requisito:cumplido`, `requisito:parcial`, `requisito:pendiente` |
| Planificación | `estado:planificado` (trabajo futuro con sprint y fechas), `registro-retroactivo` (issue escrito después del trabajo; sus fechas salen del commit) |

Las etiquetas `prioridad:alta/media/baja` anteriores se renombraron a `must/should/could`, de modo que
los issues existentes conservaron su prioridad.

## Épicas

| Épica | Issue | Hechos | Pendientes | Puntos hechos | Puntos pendientes |
|---|---|---|---|---|---|
| Cuentas y seguridad | #35 | 6 | 1 | 28 | 1 |
| Registro y síntomas | #36 | 7 | 1 | 20 | 3 |
| Modelo LSTM y alertas | #37 | 13 | 1 | 38 | 8 |
| Sincronización offline | #38 | 9 | 1 | 25 | 5 |
| Visión/CNN y datos | #39 | 4 | 3 | 20 | 21 |
| Asistente con IA | #40 | 6 | 0 | 15 | 0 |
| Infraestructura, CI y despliegue | #41 | 7 | 3 | 18 | 12 |
| Calidad y pruebas | #42 | 6 | 0 | 13 | 0 |
| Documentación y tesis | #43 | 3 | 2 | 10 | 11 |
| Validación en campo | #44 | 4 | 3 | 10 | 16 |
| **Total (sin las épicas)** | | **65** | **15** | **197** | **77** |

«Hechos» incluye los 8 issues de gestión y evidencias que cierra el pull request de esta entrega
(#80–#87). Las HU no suman puntos, porque sus puntos están en los requisitos que agrupan.

## Por tipo

| Tipo | Cantidad | Origen |
|---|---|---|
| Épicas | 10 | #35–#44 |
| Historias de usuario HU-01..09 | 9 | #45–#53 |
| Requisitos RF-01..18 y RNF-01..08 | 26 | #1–#32 (creados el 27-oct y el 8-nov) |
| Tareas e historias técnicas | 11 + 7 planificadas | #54–#59, #61–#65, #88–#92, #95, #96 |
| Bugs | 14 | #66–#79: los 10 de las pruebas en emulador y 4 del historial |
| Pruebas y evidencias | 6 + 2 planificadas | #80–#85, #93, #94 |
| Documentación | 3 + 2 planificadas | #60, #86, #87, #97, #98 |
| **Total** | **90** | |

## Prioridad del trabajo pendiente

| Prioridad | Issues |
|---|---|
| must | Despliegue con HTTPS (#88), aviso de privacidad (#90), revisión veterinaria (#92), prueba de campo (#93), gama baja real (#17), tesis (#97), sustentación (#98) |
| should | Protección de ramas (#22), Dependabot (#89), fotos al restaurar (#91), SUS (#94) |
| could | CNN con fotos reales (#11, #95), LSTM con máscara y datos reales (#96) |
