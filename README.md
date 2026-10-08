<div align="center">

# 🎬 SinFlix

**Catálogo de películas y series para todos tus dispositivos.**

Un mismo código para **iOS · Android · Web · Windows · macOS · Linux**.

[![Flutter](https://img.shields.io/badge/Flutter-3.44%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12%2B-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Riverpod](https://img.shields.io/badge/estado-Riverpod%203-DE3E44)](https://riverpod.dev)
[![TMDB](https://img.shields.io/badge/datos-TMDB-01B4E4?logo=themoviedatabase&logoColor=white)](https://www.themoviedb.org)
[![tests](https://img.shields.io/badge/tests-131%20en%20verde-2ED573)](#tests)
[![plataformas](https://img.shields.io/badge/plataformas-6-FFC53D)](#plataformas)
[![licencia](https://img.shields.io/badge/licencia-MIT-9E9E9E)](LICENSE)

[![ci](https://github.com/StudioLexair/SinFlix/actions/workflows/ci.yml/badge.svg)](https://github.com/StudioLexair/SinFlix/actions/workflows/ci.yml)
[![release](https://github.com/StudioLexair/SinFlix/actions/workflows/release.yml/badge.svg)](https://github.com/StudioLexair/SinFlix/releases)
[![web](https://github.com/StudioLexair/SinFlix/actions/workflows/site.yml/badge.svg)](https://studiolexair.github.io/SinFlix/)

</div>

<div align="center">

### ⬇️ ¿Solo quieres usarla?

**[studiolexair.github.io/SinFlix](https://studiolexair.github.io/SinFlix/)**
detecta tu dispositivo y te da el instalador correcto: Android, Windows,
macOS, Linux o directamente el navegador.

</div>

---

## Arranca en 60 segundos, sin configurar nada

SinFlix incluye un **catálogo de demostración** con títulos ficticios, así que funciona
nada más clonarlo: ni token, ni backend, ni conexión a internet.

```bash
git clone https://github.com/StudioLexair/SinFlix.git && cd SinFlix
flutter pub get
flutter run            # o: flutter run -d chrome / -d linux / -d windows
```

Verás un aviso de «modo demo» arriba. Para pasar al catálogo real:

```bash
cp .env.example .env   # pega tu token de TMDB en TMDB_READ_TOKEN
./scripts/run.sh       # lo inyecta como --dart-define y arranca
```

> 🔑 El token de TMDB es **gratis**: crea cuenta en [themoviedb.org](https://www.themoviedb.org)
> → *Settings* → *API* → copia el **API Read Access Token**.

---

## Plataformas

| Plataforma | Estado | Comando |
|---|---|---|
| 📱 Android | ✅ | `flutter run -d <device>` |
| 🍎 iOS | ✅ | `flutter run -d <simulator>` |
| 🌐 Web | ✅ | `flutter run -d chrome` |
| 🐧 Linux | ✅ | `flutter run -d linux` |
| 🪟 Windows | ✅ | `flutter run -d windows` |
| 🍏 macOS | ✅ | `flutter run -d macos` |

El diseño es **adaptativo de verdad**, no un móvil estirado:

| Ancho | Columnas de pósters | Navegación |
|---|---|---|
| < 600 px | 2 | Barra inferior |
| 600–840 px | 3 | Barra inferior |
| 840–1200 px | 5 | Rail lateral |
| ≥ 1200 px | 7 | Rail lateral extendido + contenido centrado |

---

## Qué incluye

**Catálogo**
- Tendencias, populares, mejor valoradas, estrenos y series en emisión
- Descubrimiento con filtros por género, ordenación, año y valoración mínima
- Búsqueda multi (películas, series y personas) con retardo anti-429 y filtro por tipo
- Paginación infinita con deduplicación entre páginas

**Fichas**
- Sinopsis, géneros, ficha técnica, presupuesto y recaudación
- Reparto y equipo técnico con fotos
- **Temporadas y episodios** desplegados bajo demanda
- Tráiler seleccionado automáticamente (prioriza oficial > tráiler > teaser)
- Similares y recomendaciones

**Cuentas y Mi lista**
- Registro, acceso y recuperación de contraseña con **Supabase**
- Mi lista sincronizada entre dispositivos en tiempo real (Supabase Realtime)
- Estados de seguimiento: pendiente / viendo / completado, con progreso %
- «Continuar viendo» en la portada
- **Modo local**: sin backend, la sesión y la lista se guardan en el dispositivo

**Producto**
- Tema oscuro y claro, con preferencia persistida
- Filtro de contenido para adultos configurable
- Estados de carga con *shimmer*, errores accionables y reintentos
- Aviso de modo demo con instrucciones para salir de él

---

## Arquitectura

```
lib/
├── core/           Sin dependencias de negocio: config, red, tema, utils, widgets base
├── domain/         Entidades y contratos de repositorio. Cero imports de Flutter.
├── data/           Mapeadores de TMDB, fuentes de datos y repositorios concretos
└── presentation/   Providers (Riverpod), router, shell, pantallas y widgets
```

La regla que sostiene todo: **la UI depende de interfaces, nunca de implementaciones**.

```
presentation  ──▶  domain (interfaces)  ◀──  data (TMDB / Supabase / local)
```

Eso permite dos cosas que en este proyecto no son teóricas:

1. **Cambiar de fuente de datos sin tocar la UI.** `MediaRepository` tiene dos
   implementaciones —`TmdbMediaSource` y `DemoMediaSource`— y se elige en tiempo
   de ejecución según la configuración. Las pantallas no saben cuál están usando.
2. **Funcionar sin backend.** `AuthRepository` y `WatchlistRepository` tienen
   versión Supabase y versión local. Sin credenciales, la app degrada a modo
   local en vez de romperse.

📐 Detalle completo en **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**.

---

## Stack

| Capa | Tecnología | Por qué |
|---|---|---|
| UI | Flutter 3.44+ / Material 3 | Un código, seis plataformas |
| Estado | Riverpod 3 | Composición, familias y streams sin `BuildContext` |
| Rutas | go_router 18 | `StatefulShellRoute` con historial por pestaña + redirección por sesión |
| Red | Dio 5 | Interceptores, timeout y cancelación |
| Backend | Supabase | Postgres + Auth + Realtime, sin servidores propios |
| Local | shared_preferences | Preferencias y Mi lista sin conexión |
| Imágenes | cached_network_image | Caché en disco y memoria |
| Datos | TMDB API v3 | Catálogo real, gratuito |

---

## Automatización (CI/CD)

Nada se compila a mano:

| Al pasar esto… | …ocurre esto |
|---|---|
| push a `main` o un PR | formato → análisis (cero warnings) → 131 tests → build web de humo |
| un tag `v*.*.*` | se compilan Android, Web, Windows, Linux y macOS (Intel y Apple Silicon), se publica el **Release** con binarios y checksums SHA-256, y se actualiza la web de descarga |
| cambios en la web o la app | se redepliega **[studiolexair.github.io/SinFlix](https://studiolexair.github.io/SinFlix/)** |

El detalle (convención de nombres de artefactos, firmado de Android, por qué
`release.json` se genera en el runner y no en el navegador) está en
**[docs/CI-CD.md](docs/CI-CD.md)**.

### Escala

El diseño del esquema está pensado para sostener **~50.000 usuarios activos
sobre el plan gratuito de Supabase**: filas más delgadas, sin índices muertos,
RLS evaluado una vez por consulta, tope anti-abuso y autovacuum agresivo. Los
números y el punto exacto en que conviene pasar a Pro, en
**[docs/SCALING.md](docs/SCALING.md)**.

---

## Configuración

Todas las variables se inyectan con `--dart-define` (quedan embebidas en el binario;
nunca hay un archivo de secretos dentro del bundle). **Todas son opcionales.**

| Variable | Efecto si falta |
|---|---|
| `TMDB_READ_TOKEN` | Catálogo de demo |
| `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY` | Sesión y lista en local |
| `TMDB_LANGUAGE` / `TMDB_REGION` | `es-ES` / `ES` |
| `APP_ENV` | `development` |

Guía paso a paso (TMDB, Supabase, migraciones, RLS y publicación por
plataforma) en **[docs/SETUP.md](docs/SETUP.md)**.

### 🔒 Sobre los secretos

- `.env` está en `.gitignore`. `.env.example` solo documenta las claves.
- `scripts/run.sh` **imprime los nombres de las variables, nunca sus valores**.
- La clave pública de Supabase va empaquetada en la app **a propósito**: es
  pública por diseño. Lo que protege los datos de cada usuario son las políticas
  **RLS** que crea [`supabase/migrations/0001_initial_schema.sql`](supabase/migrations/0001_initial_schema.sql).
  Nunca uses la *secret key* en una app cliente.
- Si un token acaba en un commit, un issue o un chat, **da por comprometido y
  revócalo**. No hay forma de «despublicarlo».

---

## Tests

```bash
flutter test
```

| Suite | Qué cubre |
|---|---|
| `test/data/media_mapper_test.dart` | Parseo del JSON real de TMDB: películas vs. series (`title`/`name`, `release_date`/`first_air_date`), `append_to_response`, y tolerancia a datos ausentes |
| `test/data/local_watchlist_repository_test.dart` | Mi lista local: toggle, estados, progreso, aislamiento por usuario, persistencia y recuperación de datos corruptos |
| `test/data/json_utils_test.dart` | Lectores tolerantes ante los tipos inconsistentes de la API |
| `test/domain/entities_test.dart` | `MediaId`, URLs del CDN, ordenación de tráilers |
| `test/core/*` | Formateadores y validadores de formularios |
| `test/compile_coverage_test.dart` | Construye **todas** las pantallas y widgets: garantía de que el árbol completo compila |
| `test/app_smoke_test.dart` | Arranque real: router, redirección sin sesión, login local y carga del catálogo demo |

> `app_smoke_test.dart` bombea la app completa y necesita ~2 GB de RAM libres.
> Si tu CI va justo de memoria, ejecuta el resto con
> `flutter test test/core test/domain test/data test/compile_coverage_test.dart`.

---

## Estructura del repositorio

```
├── lib/                       Código de la aplicación (66 archivos)
├── test/                      131 tests
├── assets/data/               Catálogo de demo (títulos ficticios)
├── supabase/migrations/       Esquema, índices, triggers, RLS, Realtime y optimizaciones de escala
├── scripts/
│   ├── run.sh                 Arranca inyectando .env como --dart-define
│   └── create_repo.sh         Crea el repo y sube el primer commit
├── site/                      Web de descarga (GitHub Pages, autocontenida)
├── .github/
│   ├── workflows/             ci.yml · release.yml · site.yml
│   ├── ISSUE_TEMPLATE/        Plantillas de fallo y mejora
│   └── PULL_REQUEST_TEMPLATE.md
├── docs/
│   ├── SETUP.md               Guía de configuración completa
│   ├── ARCHITECTURE.md        Decisiones de arquitectura
│   ├── CI-CD.md               Qué se compila solo, cuándo y cómo
│   └── SCALING.md             Hasta dónde llega el free tier, con números
├── android/ ios/ web/         Proyectos de plataforma generados
├── linux/ macos/ windows/
├── CHANGELOG.md · CONTRIBUTING.md · SECURITY.md
├── .env.example               Plantilla de configuración
└── pubspec.yaml
```

---

## Reconocimientos

Este producto usa la API de [TMDB](https://www.themoviedb.org) pero **no está
avalado ni certificado por TMDB**.

Los títulos del catálogo de demo son **inventados**: no existe ninguna de esas
películas o series, y ninguna persona del reparto es real.

SinFlix es una aplicación de demostración. **No reproduce ni aloja contenido**:
solo muestra información pública de catálogos.

## Licencia

[MIT](LICENSE)
