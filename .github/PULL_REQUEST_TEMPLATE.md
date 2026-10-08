<!--
  Guía rápida: qué cambia, por qué, y cómo lo has probado.
  Borra las secciones que no apliquen. Un PR pequeño y claro se revisa y se
  mergea mucho antes que uno grande y ambiguo.
-->

## Qué cambia

<!-- Una o dos frases. Si necesitas tres párrafos, probablemente sean dos PRs. -->

## Por qué

<!-- Qué problema resuelve o qué comportamiento incorrecto corrige.
     Enlaza el issue si lo hay: Fixes #123 -->

## Cómo lo he probado

<!-- Comandos, plataformas donde lo has mirado, capturas si es UI.
     Si tocas UI: ¿lo has visto en ancho estrecho Y ancho? -->

- [ ] `flutter analyze --fatal-infos --fatal-warnings` sin avisos
- [ ] `dart format --output=none --set-exit-if-changed lib test` limpio
- [ ] `flutter test` en verde (o explico por qué un test cambia)

## Checklist

- [ ] No he añadido secretos, tokens ni claves (tampoco en capturas).
- [ ] Si cambio el esquema de Supabase, es una **migración nueva**
      (`supabase/migrations/00XX_...`), no una edición de una ya aplicada.
- [ ] Si añado una dependencia, he comprobado que no obliga a `build_runner`
      (el proyecto lo evita a propósito: ver docs/ARCHITECTURE.md, decisión 5).
- [ ] He actualizado la documentación si cambia algo de lo que explica
      (`README.md`, `docs/SETUP.md`, `docs/ARCHITECTURE.md`, `docs/CI-CD.md`).
- [ ] Si cambio nombres de artefactos de release, he actualizado también las
      reglas de emparejado en `site/index.html` (ver docs/CI-CD.md).
