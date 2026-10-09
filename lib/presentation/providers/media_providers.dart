import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/query_corrector.dart';
import '../../domain/entities/genre.dart';
import '../../domain/entities/media_details.dart';
import '../../domain/entities/media_id.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/media_type.dart';
import '../../domain/entities/season.dart';
import '../../domain/repositories/media_repository.dart';
import 'core_providers.dart';

// ══════════════════════════════════════════════════════════════════════════
//  Géneros
// ══════════════════════════════════════════════════════════════════════════

/// «Lo mejor de hoy»: tendencias de las últimas 24 h. El cliente lo pidió
/// explícito en portada, separado de la semanal.
final FutureProvider<List<MediaItem>> trendingTodayProvider =
    FutureProvider<List<MediaItem>>(
      (Ref ref) =>
          ref.watch(mediaRepositoryProvider).getTrending(timeWindow: 'day'),
    );

/// «Lo mejor de la semana»: tendencias de los últimos 7 días.
final FutureProvider<List<MediaItem>> trendingWeekProvider =
    FutureProvider<List<MediaItem>>(
      (Ref ref) =>
          ref.watch(mediaRepositoryProvider).getTrending(timeWindow: 'week'),
    );

final FutureProvider<List<Genre>> movieGenresProvider =
    FutureProvider<List<Genre>>(
      (Ref ref) =>
          ref.watch(mediaRepositoryProvider).getGenres(MediaType.movie),
    );

final FutureProvider<List<Genre>> tvGenresProvider =
    FutureProvider<List<Genre>>(
      (Ref ref) => ref.watch(mediaRepositoryProvider).getGenres(MediaType.tv),
    );

/// Mapa `id → nombre` combinando ambos catálogos.
///
/// Sirve para traducir los `genre_ids` de cualquier listado sin pedir los
/// géneros en cada pantalla. Los identificadores de TMDB comparten espacio de
/// nombres, así que la fusión es segura.
final FutureProvider<Map<int, String>> genreNamesProvider =
    FutureProvider<Map<int, String>>((Ref ref) async {
      final MediaRepository repository = ref.watch(mediaRepositoryProvider);
      final List<Genre> movies = await repository.getGenres(MediaType.movie);
      final List<Genre> tv = await repository.getGenres(MediaType.tv);
      return <int, String>{
        for (final Genre g in movies) g.id: g.name,
        for (final Genre g in tv) g.id: g.name,
      };
    });

/// Nombres de género de un título, o lista vacía mientras se cargan.
final itemGenreNamesProvider = Provider.family<List<String>, MediaItem>((
  Ref ref,
  MediaItem item,
) {
  final Map<int, String>? names = ref.watch(genreNamesProvider).value;
  if (names == null) return const <String>[];
  return item.genreIds
      .map((int id) => names[id])
      .whereType<String>()
      .take(3)
      .toList(growable: false);
});

// ══════════════════════════════════════════════════════════════════════════
//  Portada (home)
// ══════════════════════════════════════════════════════════════════════════

/// Todo lo que se pinta en la pantalla de inicio, resuelto en paralelo.
class HomeFeed extends Equatable {
  const HomeFeed({
    required this.trending,
    required this.popularMovies,
    required this.topRatedMovies,
    required this.upcoming,
    required this.popularSeries,
    required this.topRatedSeries,
    required this.onTheAir,
  });

  const HomeFeed.empty()
    : trending = const <MediaItem>[],
      popularMovies = const <MediaItem>[],
      topRatedMovies = const <MediaItem>[],
      upcoming = const <MediaItem>[],
      popularSeries = const <MediaItem>[],
      topRatedSeries = const <MediaItem>[],
      onTheAir = const <MediaItem>[];

  final List<MediaItem> trending;
  final List<MediaItem> popularMovies;
  final List<MediaItem> topRatedMovies;
  final List<MediaItem> upcoming;
  final List<MediaItem> popularSeries;
  final List<MediaItem> topRatedSeries;
  final List<MediaItem> onTheAir;

  /// Título destacado del carrusel principal: el más popular con fondo.
  MediaItem? get hero {
    for (final MediaItem item in trending) {
      if (item.hasBackdrop) return item;
    }
    return trending.isEmpty ? null : trending.first;
  }

  bool get isEmpty =>
      trending.isEmpty && popularMovies.isEmpty && popularSeries.isEmpty;

  @override
  List<Object?> get props => <Object?>[
    trending,
    popularMovies,
    topRatedMovies,
    upcoming,
    popularSeries,
    topRatedSeries,
    onTheAir,
  ];
}

class HomeFeedNotifier extends AsyncNotifier<HomeFeed> {
  @override
  Future<HomeFeed> build() => _load();

  /// Recarga explícita (gesto de arrastrar hacia abajo).
  Future<void> refresh() async {
    state = const AsyncValue<HomeFeed>.loading();
    state = await AsyncValue.guard(_load);
  }

  Future<HomeFeed> _load() async {
    final MediaRepository repository = ref.watch(mediaRepositoryProvider);
    final bool excludeAdult = !ref.watch(adultContentProvider);

    // Cada fila se pide por separado y en paralelo. Si una falla, las demás se
    // muestran igual: es mucho mejor que una pantalla de error completa por un
    // único endpoint caído.
    final List<_RowTask> tasks = <_RowTask>[
      _RowTask('trending', () => repository.getTrending(limit: 20)),
      _RowTask(
        'popularMovies',
        () => repository.getPopular(MediaType.movie).then(_items),
      ),
      _RowTask(
        'topRatedMovies',
        () => repository.getTopRated(MediaType.movie).then(_items),
      ),
      _RowTask(
        'upcoming',
        () => repository.getUpcomingOrOnTheAir(MediaType.movie).then(_items),
      ),
      _RowTask(
        'popularSeries',
        () => repository.getPopular(MediaType.tv).then(_items),
      ),
      _RowTask(
        'topRatedSeries',
        () => repository.getTopRated(MediaType.tv).then(_items),
      ),
      _RowTask(
        'onTheAir',
        () => repository.getUpcomingOrOnTheAir(MediaType.tv).then(_items),
      ),
    ];

    final Map<String, List<MediaItem>> results = <String, List<MediaItem>>{};
    Object? firstError;
    StackTrace? firstStack;
    int failures = 0;

    await Future.wait<void>(
      tasks.map((_RowTask task) async {
        try {
          List<MediaItem> items = await task.run();
          if (excludeAdult) {
            items = items
                .where((MediaItem i) => !i.adult)
                .toList(growable: false);
          }
          results[task.name] = items;
        } catch (error, stackTrace) {
          failures++;
          firstError ??= error;
          firstStack ??= stackTrace;
          results[task.name] = const <MediaItem>[];
        }
      }),
    );

    // Solo se propaga el error si TODAS las filas fallaron: en ese caso no hay
    // nada que mostrar y conviene explicarlo en vez de pintar una portada vacía.
    if (failures == tasks.length && firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStack ?? StackTrace.current);
    }

    List<MediaItem> row(String name) => results[name] ?? const <MediaItem>[];

    return HomeFeed(
      trending: row('trending'),
      popularMovies: row('popularMovies'),
      topRatedMovies: row('topRatedMovies'),
      upcoming: row('upcoming'),
      popularSeries: row('popularSeries'),
      topRatedSeries: row('topRatedSeries'),
      onTheAir: row('onTheAir'),
    );
  }

  static List<MediaItem> _items(MediaPage page) => page.items;
}

final AsyncNotifierProvider<HomeFeedNotifier, HomeFeed> homeFeedProvider =
    AsyncNotifierProvider<HomeFeedNotifier, HomeFeed>(HomeFeedNotifier.new);

class _RowTask {
  const _RowTask(this.name, this.run);
  final String name;
  final Future<List<MediaItem>> Function() run;
}

// ══════════════════════════════════════════════════════════════════════════
//  Catálogo paginado (Películas / Series / Descubrir)
// ══════════════════════════════════════════════════════════════════════════

/// Lista predefinida que se quiere mostrar.
enum CatalogFeed {
  popular('Populares'),
  topRated('Mejor valoradas'),
  upcoming('Estrenos'),
  nowPlaying('En cines'),
  discover('Descubrir');

  const CatalogFeed(this.label);
  final String label;
}

/// Clave de familia: qué lista y con qué filtros.
///
/// Implementa igualdad por valor, que es lo que Riverpod usa para decidir si
/// reutiliza o recrea el notifier.
class CatalogQuery extends Equatable {
  const CatalogQuery({
    required this.type,
    this.feed = CatalogFeed.popular,
    this.genreIds = const <int>[],
    this.sortBy,
    this.minVoteAverage,
    this.fromYear,
    this.toYear,
  });

  final MediaType type;
  final CatalogFeed feed;
  final List<int> genreIds;
  final String? sortBy;
  final double? minVoteAverage;
  final int? fromYear;
  final int? toYear;

  /// `true` si hay algún filtro activo, para resaltarlo en la UI.
  bool get hasFilters =>
      genreIds.isNotEmpty ||
      sortBy != null ||
      minVoteAverage != null ||
      fromYear != null ||
      toYear != null;

  int get activeFilterCount =>
      (genreIds.isEmpty ? 0 : 1) +
      (sortBy == null ? 0 : 1) +
      (minVoteAverage == null ? 0 : 1) +
      (fromYear == null && toYear == null ? 0 : 1);

  CatalogQuery copyWith({
    MediaType? type,
    CatalogFeed? feed,
    List<int>? genreIds,
    String? sortBy,
    double? minVoteAverage,
    int? fromYear,
    int? toYear,
  }) => CatalogQuery(
    type: type ?? this.type,
    feed: feed ?? this.feed,
    genreIds: genreIds ?? this.genreIds,
    sortBy: sortBy ?? this.sortBy,
    minVoteAverage: minVoteAverage ?? this.minVoteAverage,
    fromYear: fromYear ?? this.fromYear,
    toYear: toYear ?? this.toYear,
  );

  @override
  List<Object?> get props => <Object?>[
    type,
    feed,
    genreIds,
    sortBy,
    minVoteAverage,
    fromYear,
    toYear,
  ];
}

/// Estado de una lista paginada, con carga adicional y error recuperable.
class PagedMedia extends Equatable {
  const PagedMedia({
    this.items = const <MediaItem>[],
    this.page = 0,
    this.hasMore = true,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.isDemo = false,
  });

  final List<MediaItem> items;
  final int page;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final AppException? error;

  /// `true` si los datos vienen del catálogo local de demostración.
  final bool isDemo;

  bool get isEmpty => items.isEmpty && !isLoading;
  bool get hasError => error != null;

  PagedMedia copyWith({
    List<MediaItem>? items,
    int? page,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    AppException? error,
    bool clearError = false,
    bool? isDemo,
  }) => PagedMedia(
    items: items ?? this.items,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    error: clearError ? null : (error ?? this.error),
    isDemo: isDemo ?? this.isDemo,
  );

  @override
  List<Object?> get props => <Object?>[
    items,
    page,
    hasMore,
    isLoading,
    isLoadingMore,
    error,
    isDemo,
  ];
}

class CatalogNotifier extends Notifier<PagedMedia> {
  CatalogNotifier(this.query);

  final CatalogQuery query;

  @override
  PagedMedia build() {
    // La carga se difiere un microtask: modificar `state` durante `build` no
    // está permitido. Así la primera pantalla pinta su esqueleto de carga.
    Future.microtask(() {
      if (ref.mounted) load();
    });
    return PagedMedia(isLoading: true, isDemo: ref.read(demoModeProvider));
  }

  /// Carga (o recarga) la primera página.
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final MediaPage result = await _fetch(1);
      if (!ref.mounted) return;
      state = PagedMedia(
        items: result.items,
        page: result.page,
        hasMore: result.hasMore,
        isDemo: ref.read(demoModeProvider),
      );
    } on AppException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, error: error);
    } catch (error, stackTrace) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: AppException(
          kind: AppFailureKind.unknown,
          message: 'No se pudo cargar el catálogo',
          detail: error.toString(),
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Añade la página siguiente al final de la lista.
  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final MediaPage result = await _fetch(state.page + 1);
      if (!ref.mounted) return;

      // TMDB puede devolver títulos repetidos entre páginas cuando el ranking
      // cambia mientras se navega; se deduplican para no pintar dobletes.
      final Set<String> seen = state.items
          .map((MediaItem i) => i.uniqueKey)
          .toSet();
      final List<MediaItem> fresh = result.items
          .where((MediaItem i) => seen.add(i.uniqueKey))
          .toList(growable: false);

      state = state.copyWith(
        items: <MediaItem>[...state.items, ...fresh],
        page: result.page,
        hasMore: result.hasMore && fresh.isNotEmpty,
        isLoadingMore: false,
      );
    } on AppException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoadingMore: false, error: error);
    } catch (_) {
      // Fallo inesperado al paginar: se conserva lo ya cargado y se permite
      // reintentar, en vez de vaciar la lista.
      if (!ref.mounted) return;
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<MediaPage> _fetch(int page) {
    final MediaRepository repository = ref.read(mediaRepositoryProvider);
    return switch (query.feed) {
      CatalogFeed.popular => repository.getPopular(query.type, page: page),
      CatalogFeed.topRated => repository.getTopRated(query.type, page: page),
      CatalogFeed.upcoming => repository.getUpcomingOrOnTheAir(
        query.type,
        page: page,
      ),
      CatalogFeed.nowPlaying => repository.getNowPlaying(page: page),
      CatalogFeed.discover => repository.discover(
        DiscoverQuery(
          type: query.type,
          genreIds: query.genreIds,
          sortBy: query.sortBy ?? 'popularity.desc',
          page: page,
          minVoteAverage: query.minVoteAverage,
          fromYear: query.fromYear,
          toYear: query.toYear,
          includeAdult: ref.read(adultContentProvider),
        ),
      ),
    };
  }
}

final catalogProvider =
    NotifierProvider.family<CatalogNotifier, PagedMedia, CatalogQuery>(
      CatalogNotifier.new,
    );

// ══════════════════════════════════════════════════════════════════════════
//  Búsqueda
// ══════════════════════════════════════════════════════════════════════════

/// Texto escrito por el usuario. Se actualiza con retardo desde la UI para no
/// lanzar una petición por cada pulsación.
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) {
    if (state == value) return;
    state = value;
  }

  void clear() => set('');
}

final NotifierProvider<SearchQueryNotifier, String> searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

/// Filtro de tipo: `null` busca en todo (multi).
class SearchTypeNotifier extends Notifier<MediaType?> {
  @override
  MediaType? build() => null;

  void set(MediaType? type) => state = type;
}

final NotifierProvider<SearchTypeNotifier, MediaType?> searchTypeProvider =
    NotifierProvider<SearchTypeNotifier, MediaType?>(SearchTypeNotifier.new);

/// Longitud mínima para considerar que hay una búsqueda intencionada.
const int kMinSearchLength = 2;

/// «Quizás quisiste decir»: corrección de erratas contra el léxico local.
final Provider<String?> searchSuggestionProvider = Provider<String?>((Ref ref) {
  final String query = ref.watch(searchQueryProvider).trim();
  if (query.length < kMinSearchLength) return null;
  final AsyncValue<MediaPage> results = ref.watch(searchResultsProvider);
  final int n = results.value?.items.length ?? 0;
  if (n > 2) return null; // con resultados decentes no se mete nadie
  final String? sugerencia = QueryCorrector.suggest(query);
  if (sugerencia == null) return null;
  return normalizeQuery(sugerencia) == normalizeQuery(query)
      ? null
      : sugerencia;
});

final FutureProvider<MediaPage> searchResultsProvider =
    FutureProvider<MediaPage>((Ref ref) async {
      final String query = ref.watch(searchQueryProvider).trim();
      final MediaType? type = ref.watch(searchTypeProvider);

      if (query.length < kMinSearchLength) return const MediaPage.empty();

      final MediaPage page = await ref
          .watch(mediaRepositoryProvider)
          .search(query, type: type);
      LexiconStore.instance.addMany(page.items.map((MediaItem i) => i.title));
      return page;
    });

/// Sugerencias cuando el campo está vacío: tendencias del momento.
final FutureProvider<List<MediaItem>> searchSuggestionsProvider =
    FutureProvider<List<MediaItem>>((Ref ref) async {
      final bool hasQuery =
          ref.watch(searchQueryProvider).trim().length >= kMinSearchLength;
      if (hasQuery) return const <MediaItem>[];
      return ref.watch(mediaRepositoryProvider).getTrending(limit: 10);
    });

// ══════════════════════════════════════════════════════════════════════════
//  Detalle
// ══════════════════════════════════════════════════════════════════════════

/// Ficha completa de un título.
final mediaDetailsProvider = FutureProvider.family<MediaDetails, MediaId>(
  (Ref ref, MediaId id) =>
      ref.watch(mediaRepositoryProvider).getDetails(id.id, id.type),
);

/// Episodios de una temporada. Se pide bajo demanda al desplegar la temporada.
final seasonEpisodesProvider =
    FutureProvider.family<List<Episode>, ({int seriesId, int season})>(
      (Ref ref, ({int seriesId, int season}) key) => ref
          .watch(mediaRepositoryProvider)
          .getSeasonEpisodes(key.seriesId, key.season),
    );

/// Título destacado actual de la portada (para el carrusel principal).
class HeroIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) {
    if (state == index) return;
    state = index;
  }

  void next(int total) {
    if (total <= 1) return;
    state = (state + 1) % total;
  }
}

final NotifierProvider<HeroIndexNotifier, int> heroIndexProvider =
    NotifierProvider<HeroIndexNotifier, int>(HeroIndexNotifier.new);
