## Descripción

<!-- Qué cambia y por qué, en pocas líneas. -->

## Issue enlazado

Cierra #

## Cómo se probó

- [ ] `./mvnw verify` (backend: pruebas, JaCoCo, Checkstyle y SpotBugs)
- [ ] `flutter analyze --fatal-infos` y `flutter test --coverage` (mobile)
- [ ] `pytest --cov`, `ruff check` y `mypy` (ml)
- [ ] Pruebas de mutación si cambió `auth`, `sync` o la lógica de `ml/` (ver `docs/gestion/pruebas/calidad.md`)
- [ ] Prueba manual o en emulador (describir abajo)
- [ ] No aplica: solo documentación

## Riesgos y cómo revertir

<!-- Qué podría romperse, a quién afecta y cómo deshacerlo. -->

## Revisión antes de integrar

- [ ] Ningún archivo es dependencia, build, secreto, `local.properties`, CSV ni `.keras`/`.h5`
- [ ] Commits en español, cortos y a nombre del autor
- [ ] Documentación y `docs/REQUISITOS.md` al día si cambia un requisito
- [ ] CI en verde

## Pendiente
