# Changelog

Todos los cambios notables de CarimarShow se documentan aquí.

Formato basado en [Keep a Changelog](https://keepachangelog.com/es/1.1.0/) y
este proyecto adhiere [SemVer](https://semver.org/lang/es/).

## [1.0.0] — CarimarShow, fase 1

Primera versión con la marca del cliente y la «etapa informativa» completa.

### Añadido
- **Caché de catálogo en disco** (cache-first en el fallo): si hay red se
  consulta TMDB y se guarda copia; si no hay red, timeout, 429 o 5xx, se sirve
  la última copia buena. Índice LRU con tope de 2 MB.
- **Botón «Liberar espacio»** en Perfil: vacía la caché y dice cuántos bytes
  liberó.
- **Compartir la lista de favoritos**: diálogo con nota final, share-sheet
  nativo (`share_plus`) con copia al portapapeles como reserva, y pie con los
  datos del negocio.
- **Banner promocional configurable** en portada (interruptor y texto editable
  en Perfil; la × lo desactiva).
- **Filas «Lo mejor de hoy» y «Lo mejor de la semana»** explícitas en portada.
- **Pantalla «El negocio»** (`/negocio`) con dirección, horario, teléfonos
  (`tel:`) y correo (`mailto:`), más el logotipo.
- **Rebrand completo a CarimarShow**: repo, paquete Dart `carimarshow`,
  bundle ids `com.carimarshow.app`, nombres visibles en las seis plataformas,
  paleta turquesa/menta del logotipo, 37 iconos generados desde el logo real,
  web y og-image recoloreadas.

### Cambiado
- El redirect del router ya no puede dejar al usuario clavado en `/splash`.
- Proyectos Supabase renombrados a `carimarshow-production` / `-staging`.

## [Sin publicar]

### Añadido
- **CI/CD completo** (`.github/workflows/`):
  - `ci.yml` — formato, análisis estricto, 131 tests y build web de humo en
    cada push y PR.
  - `release.yml` — compilación de Android, Web, Windows, Linux y macOS
    (Apple Silicon e Intel) al crear un tag `v*`, con Release, checksums
    SHA-256 y notas de versión generadas.
  - `site.yml` — web de descarga con detección de dispositivo + app web
    compilada, publicadas en GitHub Pages.
- **Web de descarga** (`site/`): página autocontenida que detecta el sistema
  del visitante (y el chip, en Mac), enlaza el binario correcto de GitHub y
  explica la instalación de cada plataforma. Lee un `release.json` estático
  generado en el CI para no depender de los límites de la API pública.
- **Migración `0002_scale_optimizations.sql`**: optimizaciones de escala para
  el plan gratuito de Supabase (ver más abajo y `docs/SCALING.md`).
- **Firmado de release de Android** configurable vía `android/key.properties`
  con keystore PKCS12, degradando a firma de debug si no existe.
- **Paquete `.deb`** para Debian/Ubuntu con entrada de menú e icono.
- `docs/SCALING.md` — análisis con números de hasta dónde llega el free tier.
- `docs/CI-CD.md` — cómo funciona el pipeline y la convención de nombres.
- `CONTRIBUTING.md`, `SECURITY.md` y plantillas de issue y pull request.

### Cambiado
- `SupabaseWatchlistRepository.add()` deja de enviar `overview` y
  `original_language`: la migración 0002 eliminó esas columnas. La decodificación
  sigue leyéndolas de forma tolerante, así que el código funciona contra
  esquemas con 0001 y con 0002.
- Recortes defensivos de longitud al escribir en `watchlist` para respetar los
  nuevos límites `varchar(n)`.

### Optimizado (escala)
- `watchlist` pasa de ~500 B a ~245 B por fila al retirar la sinopsis
  denormalizada, que nunca se pintaba en la lista. ~2× más usuarios en el
  mismo disco.
- Eliminados los dos índices secundarios de `watchlist`: ninguno se usaba y
  costaban ~72 B/fila. La PK ya cubre el único filtro que hace la app.
- Políticas RLS reescritas como `(select auth.uid())`: la función se evalúa
  una vez por consulta en lugar de por fila.
- Trigger de tope anti-abuso: máx. 1.000 títulos por usuario (SQLSTATE 54000).
- Autovacuum de `watchlist` y `profiles` al 2% / 5% para que el churn alto no
  llene el disco de tuplas muertas.

### Infraestructura
- Proyectos Supabase renombrados a `carimarshow-production` y `carimarshow-staging`
  (antes `velmora-*`), con el esquema previo vaciado por completo.
- Autenticación de Supabase con **autoconfirm activado**: el free tier solo
  envía 2 correos/hora, inviable para confirmación de registro a escala.
- Repositorio hecho público para habilitar GitHub Pages en plan gratuito,
  descargas sin autenticación y minutos de Actions ilimitados.

## [0.1.0] — base importada

### Añadido
- App Flutter multiplataforma: Android, iOS, Web, Windows, macOS y Linux.
- Catálogo con TMDB: tendencias, populares, mejor valoradas, estrenos, series
  en emisión, descubrimiento con filtros y búsqueda multi con anti-429.
- Fichas completas: reparto, equipo, temporadas y episodios bajo demanda,
  tráiler seleccionado automáticamente, similares y recomendaciones.
- Cuentas y «Mi lista» con Supabase (RLS + Realtime) o en local sin backend.
- Estados de seguimiento (pendiente / viendo / completado) y progreso.
- Catálogo de demostración con títulos ficticios: la app arranca sin
  configurar nada.
- Arquitectura de cuatro capas (`core`, `domain`, `data`, `presentation`).
- 131 tests: mapeadores, repositorio local, utilidades y cobertura de UI.
- Diseño adaptable de 2 a 7 columnas con barra inferior o rail lateral.
- Tema claro/oscuro persistido y filtro de contenido para adultos.

[Sin publicar]: https://github.com/StudioLexair/CarimarShow/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/StudioLexair/CarimarShow/releases/tag/v0.1.0
