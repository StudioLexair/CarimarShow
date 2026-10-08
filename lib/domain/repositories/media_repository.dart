import '../entities/genre.dart';
import '../entities/media_details.dart';
import '../entities/media_item.dart';
import '../entities/media_type.dart';
import '../entities/season.dart';

/// Criterios de descubrimiento para `/discover`.
class DiscoverQuery {
  const DiscoverQuery({
    this.type = MediaType.movie,
    this.genreIds = const <int>[],
    this.sortBy = 'popularity.desc',
    this.page = 1,
    this.minVoteAverage,
    this.minVoteCount,
    this.year,
    this.fromYear,
    this.toYear,
    this.includeAdult = false,
    this.withOriginalLanguage,
    this.keyword,
  });

  final MediaType type;
  final List<int> genreIds;
  final String sortBy;
  final int page;
  final double? minVoteAverage;
  final int? minVoteCount;
  final int? year;
  final int? fromYear;
  final int? toYear;
  final bool includeAdult;
  final String? withOriginalLanguage;
  final String? keyword;

  DiscoverQuery copyWith({
    MediaType? type,
    List<int>? genreIds,
    String? sortBy,
    int? page,
    double? minVoteAverage,
    int? minVoteCount,
    int? year,
    int? fromYear,
    int? toYear,
    bool? includeAdult,
    String? withOriginalLanguage,
    String? keyword,
  }) => DiscoverQuery(
    type: type ?? this.type,
    genreIds: genreIds ?? this.genreIds,
    sortBy: sortBy ?? this.sortBy,
    page: page ?? this.page,
    minVoteAverage: minVoteAverage ?? this.minVoteAverage,
    minVoteCount: minVoteCount ?? this.minVoteCount,
    year: year ?? this.year,
    fromYear: fromYear ?? this.fromYear,
    toYear: toYear ?? this.toYear,
    includeAdult: includeAdult ?? this.includeAdult,
    withOriginalLanguage: withOriginalLanguage ?? this.withOriginalLanguage,
    keyword: keyword ?? this.keyword,
  );
}

/// Resultado paginado de una consulta de catálogo.
class MediaPage {
  const MediaPage({
    required this.items,
    required this.page,
    required this.hasMore,
    this.totalResults,
  });

  const MediaPage.empty()
    : items = const <MediaItem>[],
      page = 1,
      hasMore = false,
      totalResults = 0;

  final List<MediaItem> items;
  final int page;
  final bool hasMore;
  final int? totalResults;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
}

/// Contrato del catálogo.
///
/// La capa de presentación depende **solo** de esta interfaz. Detrás puede haber
/// TMDB en directo o el catálogo de demo local: la UI no lo sabe ni le importa.
abstract interface class MediaRepository {
  /// Tendencias globales o por tipo.
  Future<List<MediaItem>> getTrending({
    MediaType type = MediaType.movie,
    String timeWindow = 'week',
    int limit = 20,
  });

  /// Populares del tipo indicado.
  Future<MediaPage> getPopular(MediaType type, {int page = 1});

  /// Mejor valorados por la comunidad.
  Future<MediaPage> getTopRated(MediaType type, {int page = 1});

  /// Próximos estrenos (películas) o en emisión (series).
  Future<MediaPage> getUpcomingOrOnTheAir(MediaType type, {int page = 1});

  /// En cines ahora mismo (solo películas).
  Future<MediaPage> getNowPlaying({int page = 1});

  /// Descubrimiento con filtros: género, orden, año, valoración mínima…
  Future<MediaPage> discover(DiscoverQuery query);

  /// Ficha completa con créditos, vídeos, similares y recomendaciones.
  Future<MediaDetails> getDetails(int id, MediaType type);

  /// Episodios de una temporada concreta.
  Future<List<Episode>> getSeasonEpisodes(int seriesId, int seasonNumber);

  /// Búsqueda multi (películas, series y personas) o filtrada por tipo.
  Future<MediaPage> search(String query, {MediaType? type, int page = 1});

  /// Listado de géneros, con caché en memoria.
  Future<List<Genre>> getGenres(MediaType type);

  /// `true` si el repositorio sirve datos reales de TMDB.
  bool get isLive;

  /// Libera recursos (cierres de cliente HTTP, temporizadores…).
  void dispose() {}
}
