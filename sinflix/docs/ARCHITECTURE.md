# Arquitectura

Este documento explica **por qué** el código está organizado así. Para el
**cómo** se configura, mira [SETUP.md](SETUP.md).

---

## Las cuatro capas

```
lib/
├── core/           ← infraestructura sin negocio
├── domain/         ← el modelo y los contratos        (sin Flutter)
├── data/           ← cómo se consiguen los datos       (TMDB, Supabase, disco)
└── presentation/   ← cómo se muestra                 (Riverpod, go_router, widgets)
```

La dependencia siempre apunta hacia dentro:

```
presentation ──▶ domain ◀── data
                  ▲
                  └────────── core
```

`domain/` no importa nada de las otras tres. Esa es la regla que hace posible
todo lo demás.

### `core/` — infraestructura reutilizable

| Carpeta | Contenido |
|---|---|
| `config/` | `Env` (variables `--dart-define`) y `AppConfig` (configuración resuelta) |
| `constants/` | Endpoints, tamaños de imagen y textos de TMDB |
| `errors/` | `AppException` y su jerarquía tipada |
| `network/` | `TmdbApiClient`: Dio + interceptores + traducción de errores |
| `theme/` | Paleta y temas claro/oscuro |
| `utils/` | Formateadores, validadores, diseño adaptable, URLs de imagen |
| `widgets/` | Piezas sin negocio: póster, errores, cabeceras, esqueletos |

### `domain/` — entidades y contratos

Entidades inmutables con igualdad por valor (`Equatable`): `MediaItem`,
`MediaDetails`, `MediaId`, `MediaType`, `Season`, `Episode`, `CastMember`,
`MediaVideo`, `Genre`, `AppUser`, `WatchlistItem`.

Y tres **interfaces** que son el corazón del diseño:

```dart
abstract interface class MediaRepository    { ... }
abstract interface class AuthRepository     { ... }
abstract interface class WatchlistRepository{ ... }
```

### `data/` — implementación

| Archivo | Responsabilidad |
|---|---|
| `mappers/json_utils.dart` | Lectores tolerantes de JSON |
| `mappers/media_mapper.dart` | **Todo** el conocimiento del formato TMDB |
| `mappers/local_codec.dart` | Serialización propia para el disco |
| `sources/tmdb_media_source.dart` | Catálogo real |
| `sources/demo_media_source.dart` | Catálogo ficticio de respaldo |
| `repositories/supabase_*` | Cuentas y lista en la nube |
| `repositories/local_*` | Cuentas y lista en el dispositivo |

### `presentation/` — estado y UI

`providers/` (Riverpod), `router/` (go_router), `shell/` (andamiaje de pestañas),
`screens/` y `widgets/`.

---

## Decisión 1: una sola entidad para películas y series

TMDB trata películas y series como recursos distintos con campos distintos:

| | Película | Serie |
|---|---|---|
| Título | `title` | `name` |
| Estreno | `release_date` | `first_air_date` |
| Duración | `runtime` | `episode_run_time[]` |

La tentación es tener `Movie` y `TvShow`. **No lo hacemos.** Todo se normaliza a
un único `MediaItem`, y el mapeador resuelve las diferencias:

```dart
final String title = Json.str(json, 'title', fallback: Json.str(json, 'name'));
final DateTime? releaseDate = Json.dateOrNull(json, 'release_date')
    ?? Json.dateOrNull(json, 'first_air_date');
```

El motivo es práctico: carruseles, rejillas, tarjetas, búsqueda y Mi lista son
**exactamente iguales** para ambos tipos. Con dos entidades, cada widget tendría
que duplicarse o llenarse de `if (item is Movie)`. Los campos exclusivos de serie
(temporadas, episodios, creadores) viven en `MediaDetails`, que solo se pide al
abrir la ficha.

### El `id` no basta: hace falta el tipo

TMDB numera películas y series en secuencias **independientes**. El `id` 155 es a
la vez una película y una serie distintas. Por eso existe `MediaId`:

```dart
class MediaId {           // clave canónica: "movie:155"
  final MediaType type;
  final int id;
  String get key  => '${type.apiValue}:$id';
  String get route => '/title/${type.apiValue}/$id';
}
```

Se usa como clave de familia en los providers, como parte de la clave primaria
en Postgres y como identificador en Mi lista. Olvidar el tipo aquí produce el
bug más difícil de rastrear de toda la app: la ficha equivocada.

---

## Decisión 2: dos implementaciones por repositorio

```dart
final Provider<MediaRepository> mediaRepositoryProvider = Provider((ref) {
  final config = ref.watch(appConfigProvider);
  return config.useDemoCatalog ? DemoMediaSource() : TmdbMediaSource(config: config);
});
```

Lo mismo para `AuthRepository` y `WatchlistRepository` (Supabase vs. local).

**Qué ganamos:** la app arranca y es totalmente navegable sin ninguna credencial.
Un clon recién descargado funciona; no hay una pantalla de configuración
obligatoria antes de ver nada. Y el código de demo no es un `if` esparcido por la
UI: es una implementación más detrás de la misma interfaz.

**El truco que lo hace barato:** `demo_catalog.json` usa **los mismos nombres de
campo que TMDB**. Así pasa por el mismo `MediaMapper` y no existe un segundo
camino de parseo que mantener. Los campos exclusivos de la ficha viven bajo
`_demo`, que la fuente de demo fusiona imitando lo que produce
`append_to_response`.

```dart
final merged = <String, dynamic>{ ...raw, ..._extras(raw), 'similar': related };
return MediaMapper.details(merged, type: type);   // el mismo mapeador
```

---

## Decisión 3: tolerancia en el parseo, no excepciones

TMDB omite campos, usa `null` donde otras APIs usarían cadena vacía y mezcla
tipos. Dos decisiones al respecto:

**Lectores tolerantes.** Todo acceso pasa por `Json.str`, `Json.intOr`,
`Json.dateOrNull`… que devuelven valores por defecto en lugar de lanzar.

**Listas indulgentes.** `mapListLenient` descarta los elementos problemáticos y
conserva el resto:

```dart
for (final item in items) {
  try {
    final mapped = mapper(item);
    if (mapped != null) result.add(mapped);
  } catch (_) { /* se descarta en silencio */ }
}
```

En un carrusel de 20 pósters, perder uno es aceptable; perder los 20 no. La
rigidez se reserva para donde importa: `getDetails` sí lanza, porque una ficha es
un todo o nada.

---

## Decisión 4: errores tipados, con mensaje ya traducido

```dart
enum AppFailureKind {
  network, unauthorized, notFound, rateLimit,
  server, client, auth, parsing, cancelled, unknown
}
```

`TmdbApiClient.mapDioException` convierte cualquier fallo de transporte en un
`AppException` con un `message` **apto para el usuario** y un `detail` para logs.

Consecuencias en la UI:

- `AppErrorView` elige icono, título y pista accionable según el `kind`. Un 401
  muestra «revisa tu `TMDB_READ_TOKEN`»; un fallo de red muestra «comprueba tu
  conexión».
- `isRetryable` decide si tiene sentido pintar el botón de reintentar.
- **No se filtra información interna** al usuario, pero el `detail` completo
  llega a los logs de desarrollo.

El `switch` sobre `DioExceptionType` es exhaustivo a propósito: cuando dio añada
un caso nuevo (ya pasó con `transformTimeout` en 5.11), el compilador obliga a
decidir qué hacer en vez de caer en silencio por un `default`.

---

## Decisión 5: Riverpod 3, sin generación de código

Se usa la API manual (`Provider`, `FutureProvider`, `StreamProvider`, `Notifier`,
`AsyncNotifier`) en lugar de `riverpod_generator`.

Motivo: **cero `build_runner`**. Un clon funciona con `flutter pub get`, sin un
paso de generación que olvidar ni archivos `.g.dart` que desincronizar. En un
proyecto de este tamaño la anotación no ahorra trabajo; lo añade.

Detalles que importan:

**Retry automático desactivado.** Riverpod 3 reintenta por defecto los providers
fallidos. Contra una API con límite de peticiones eso convierte un 429 en un
bucle de llamadas:

```dart
ProviderScope(retry: (retryCount, error) => null, ...)
```

El reintento queda en manos del usuario, con su botón.

**`ref.mounted` tras cada `await`.** En Riverpod 3, usar un `Ref` descartado
lanza `UnmountedRefException`. Todos los notifiers lo comprueban antes de tocar
`state`.

**Sin providers *legacy*.** Nada de `StateProvider` ni `StateNotifierProvider`
(movidos a `package:flutter_riverpod/legacy.dart`). Solo `Notifier` y
`AsyncNotifier`.

**Familias con clave por valor.** `CatalogQuery` y `MediaId` implementan `==`,
que es lo que Riverpod usa para decidir si reutiliza el notifier. Consecuencia
útil: cada combinación de pestaña y filtros conserva su propia paginación, así
que cambiar de pestaña y volver no te devuelve al principio.

---

## Decisión 6: la portada falla en degradado, no en bloque

La portada necesita siete listas distintas. Pedirlas con `Future.wait` a secas
haría que un solo endpoint caído tumbara la pantalla entera.

```dart
await Future.wait(tasks.map((task) async {
  try {
    results[task.name] = await task.run();
  } catch (error, stackTrace) {
    failures++;
    firstError ??= error;
    results[task.name] = const [];      // esta fila cae; las demás siguen
  }
}));

// Solo se propaga si TODAS fallaron: entonces no hay nada que mostrar.
if (failures == tasks.length && firstError != null) {
  Error.throwWithStackTrace(firstError!, firstStack ?? StackTrace.current);
}
```

El mismo criterio en la paginación: si falla la página 3, se conserva lo ya
cargado y se ofrece reintentar, en lugar de vaciar la lista.

---

## Decisión 7: Mi lista es un stream, y denormalizada

```dart
Stream<List<WatchlistItem>> watch(String userId);
```

Un stream y no un `Future` porque la lista debe reaccionar sola: marcar un título
desde la ficha actualiza la pestaña al instante, y con Supabase Realtime también
actualiza **otros dispositivos** sin recargar.

En Postgres, los datos del título (título, póster, sinopsis, nota, géneros) se
guardan **en la propia fila** en vez de quedarse solo con `tmdb_id`:

```sql
primary key (user_id, media_type, tmdb_id),
title text not null default '',
poster_path text,
overview text not null default '',
vote_average numeric(4,2) not null default 0,
genre_ids integer[] not null default '{}'
```

Cuesta unos KB por fila y a cambio la pantalla se pinta **sin una sola llamada a
TMDB**: carga instantánea y funciona sin conexión.

---

## Decisión 8: navegación por sesión en un solo sitio

`go_router` con `StatefulShellRoute.indexedStack` para las cuatro pestañas (cada
una conserva su historial y su posición de scroll) y un único `redirect` global:

```dart
if (auth.isLoading) return location == '/splash' ? null : '/splash';
if (!signedIn && !isPublic) return '/login';
if (signedIn && isPublic)   return '/home';
if (auth.hasError && !isPublic) return '/login';
return null;
```

**Ninguna pantalla comprueba la sesión por su cuenta.** Es la fuente clásica de
parpadeos y bucles: mientras se resuelve la sesión persistida se muestra el
splash, *nunca* un destello de la pantalla de login.

Un `ValueNotifier` puentea el stream de autenticación a `refreshListenable`,
para que cada cambio de sesión reevalúe las redirecciones.

---

## Decisión 9: un `CatalogScreen` para películas y series

Las pestañas de películas y series son idénticas salvo por el tipo: mismas
pestañas (populares / mejor valoradas / estrenos), mismos filtros de género,
misma ordenación, misma rejilla paginada.

```dart
class MoviesScreen extends StatelessWidget {
  Widget build(context) => const CatalogScreen(type: MediaType.movie);
}
class SeriesScreen extends StatelessWidget {
  Widget build(context) => const CatalogScreen(type: MediaType.tv);
}
```

Solo cambia el texto de una pestaña («Estrenos» vs. «En emisión») y el endpoint
que hay detrás. Cualquier mejora futura se aplica a las dos a la vez.

---

## Decisión 10: diseño adaptable de verdad

El número de columnas y el tipo de navegación salen de un único sitio
(`core/utils/responsive.dart`), no de `MediaQuery` esparcidos por los widgets:

```dart
int get posterColumns => switch (screenClass) {
  ScreenClass.compact  => 2,
  ScreenClass.medium   => 3,
  ScreenClass.expanded => 5,
  ScreenClass.large    => 7,
};

bool get usesNavigationRail => !isCompact;
double get contentMaxWidth => isDesktop ? 1400 : double.infinity;
```

`ResponsiveContainer` limita el ancho del contenido en monitores grandes para
que la interfaz no se estire de lado a lado. El mismo código da una barra
inferior en el móvil y un rail lateral con logotipo en escritorio.

---

## Rendimiento

Decisiones concretas, no intenciones:

- **Tamaño de imagen correcto.** `TmdbImages` compone la URL con el tamaño
  adecuado al uso (`w154` en listas pequeñas, `w342` en pósters, `w1280` en
  fondos). Pedir `original` para un póster de 120 px —el error más común con
  TMDB— son varios MB por imagen.
- **`append_to_response`.** La ficha completa (créditos, vídeos, similares,
  recomendaciones, palabras clave) llega en **una** petición en lugar de cinco.
- **Caché de géneros.** Se piden una vez y se reutilizan; cambian muy poco.
- **`cacheExtent` en carruseles.** Precarga las tarjetas adyacentes para que el
  desplazamiento no muestre huecos.
- **Episodios bajo demanda.** Solo se piden al desplegar una temporada.
- **Deduplicación al paginar.** TMDB puede repetir títulos entre páginas si el
  ranking cambia mientras navegas.
- **Retardo en la búsqueda.** 400 ms sin teclear antes de pedir; sin eso, cada
  pulsación es una petición y TMDB responde con un 429 inmediato.
- **Cancelación.** `TmdbMediaSource` mantiene un `CancelToken` que aborta las
  peticiones en vuelo al descartar el repositorio.
- **Autoavance del héroe que se detiene** en cuanto el usuario toca o la app deja
  de estar visible.
- **Riverpod 3 pausa los listeners fuera de vista** por defecto; no se pinta lo
  que no se ve.

---

## Qué no se ha hecho (y por qué)

Decisiones explícitas, no olvidos:

| No incluido | Motivo |
|---|---|
| **Reproducción de vídeo** | SinFlix es un catálogo: no aloja ni reproduce contenido. El tráiler se abre en el navegador con `url_launcher` |
| **Internacionalización (ARB)** | Todos los textos están centralizados en `Strings`. Migrar a `flutter gen-l10n` es mecánico cuando se necesite; añadirlo ahora sería especulativo |
| **`freezed` / `json_serializable`** | Habría que mantener los modelos a mano igualmente y obliga a `build_runner`. Con `Equatable` y mapeadores explícitos hay el mismo control y menos magia |
| **Tests de las fuentes de red** | Requerirían mocks de Dio y Supabase. Los tests se concentran donde hay lógica real: mapeadores, repositorio local, utilidades y cobertura del árbol de widgets |
| **Modo sin conexión completo** | Mi lista sí funciona sin conexión (está denormalizada). El catálogo no se cachea a disco: `cached_network_image` ya evita re-descargar imágenes |
| **Perfiles múltiples por cuenta** | Supabase lo permitiría, pero añade complejidad a RLS y a la UI sin una necesidad clara todavía |

---

## Cómo extenderlo

**Añadir una nueva lista al catálogo** (p. ej. «Películas de los 90»):

1. `CatalogFeed` — nuevo valor del enum.
2. `CatalogNotifier._fetch` — nuevo caso en el `switch`.
3. `CatalogScreen._feeds` — incluirlo en las pestañas.

**Añadir una fuente de datos** (p. ej. Trakt):

1. Implementar `MediaRepository`.
2. Cambiar `mediaRepositoryProvider`.

Ninguna pantalla se modifica en ninguno de los dos casos.

**Añadir una pantalla dentro del shell:** nueva rama en `MainTab`, nueva
`StatefulShellBranch` en el router y la pantalla. Fuera del shell: una `GoRoute`
más, como `/search` o `/profile`.
