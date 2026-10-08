import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/tmdb_constants.dart';
import '../../core/network/tmdb_api_client.dart';
import '../../domain/entities/genre.dart';
import '../../domain/entities/media_details.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/media_type.dart';
import '../../domain/entities/season.dart';
import '../../domain/repositories/media_repository.dart';
import '../mappers/media_mapper.dart';

/// Implementación del catálogo contra la API real de TMDB.
///
/// Detalles de implementación que conviene conocer al tocar esto:
///  * Los detalles se piden con `append_to_response` para evitar 5 peticiones.
///  * Los géneros se cachean en memoria: cambian muy poco y se usan en cada
///    listado para traducir `genre_ids` a nombres.
///  * `adult` se filtra de forma centralizada para respetar la preferencia.
class TmdbMediaSource implements MediaRepository {
  TmdbMediaSource({required AppConfig config, Dio? dio})
    : _client = TmdbApiClient(config: config, dio: dio),
      _cancelToken = CancelToken();

  final TmdbApiClient _client;

  /// Se cancela en [dispose] para abortar peticiones en vuelo.
  final CancelToken _cancelToken;

  /// Caché de géneros por tipo. Se rellena en la primera petición que los pida.
  final Map<MediaType, List<Genre>> _genreCache = <MediaType, List<Genre>>{};

  @override
  bool get isLive => true;

  // ══════════════════════════════════════════════════════════════════════
  //  Listados
  // ══════════════════════════════════════════════════════════════════════

  @override
  Future<List<MediaItem>> getTrending({
    MediaType type = MediaType.movie,
    String timeWindow = 'week',
    int limit = 20,
  }) async {
    // `/trending/all/{window}` mezcla películas, series y personas; las personas
    // se descartan en el mapeador.
    final String scope = switch (type) {
      MediaType.movie => 'movie',
      MediaType.tv => 'tv',
      MediaType.person => 'all',
    };
    final String window = timeWindow == TmdbTimeWindow.day.value
        ? 'day'
        : 'week';

    final List<Map<String, dynamic>> raw = await _client.getList(
      '/trending/$scope/$window',
      cancelToken: _token,
    );
    return MediaMapper.items(
      raw,
      fallbackType: type,
      excludeAdult: true,
      limit: limit,
    );
  }

  @override
  Future<MediaPage> getPopular(MediaType type, {int page = 1}) =>
      _paged('/${type.apiValue}/popular', type, page: page);

  @override
  Future<MediaPage> getTopRated(MediaType type, {int page = 1}) =>
      _paged('/${type.apiValue}/top_rated', type, page: page);

  @override
  Future<MediaPage> getUpcomingOrOnTheAir(MediaType type, {int page = 1}) =>
      type.isTv
      ? _paged('/tv/on_the_air', type, page: page)
      : _paged('/movie/upcoming', type, page: page);

  @override
  Future<MediaPage> getNowPlaying({int page = 1}) =>
      _paged('/movie/now_playing', MediaType.movie, page: page);

  @override
  Future<MediaPage> discover(DiscoverQuery query) async {
    final String type = query.type.isTv ? 'tv' : 'movie';
    // El parámetro de fecha cambia de nombre según el tipo de recurso.
    final String yearKey = query.type.isTv ? 'first_air_date_year' : 'year';
    final String fromKey = query.type.isTv
        ? 'first_air_date.gte'
        : 'release_date.gte';
    final String toKey = query.type.isTv
        ? 'first_air_date.lte'
        : 'release_date.lte';

    final Map<String, dynamic> params = <String, dynamic>{
      'page': query.page,
      'sort_by': query.sortBy,
      'include_adult': query.includeAdult,
      if (query.genreIds.isNotEmpty) 'with_genres': query.genreIds.join(','),
      if (query.minVoteAverage != null && query.minVoteAverage! > 0)
        'vote_average.gte': query.minVoteAverage,
      if (query.minVoteCount != null && query.minVoteCount! > 0)
        'vote_count.gte': query.minVoteCount,
      if (query.year != null) yearKey: query.year,
      if (query.fromYear != null) fromKey: '${query.fromYear}-01-01',
      if (query.toYear != null) toKey: '${query.toYear}-12-31',
      if (query.withOriginalLanguage != null &&
          query.withOriginalLanguage!.isNotEmpty)
        'with_original_language': query.withOriginalLanguage,
      if (query.keyword != null && query.keyword!.isNotEmpty)
        'with_keywords': query.keyword,
    };

    final PaginatedJson result = await _client.getPaginated(
      '/discover/$type',
      query: params,
      cancelToken: _token,
    );
    return MediaPage(
      items: MediaMapper.items(
        result.results,
        fallbackType: query.type,
        excludeAdult: !query.includeAdult,
      ),
      page: result.page,
      hasMore: result.hasMore,
      totalResults: result.totalResults,
    );
  }

  @override
  Future<MediaPage> search(
    String query, {
    MediaType? type,
    int page = 1,
  }) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) return const MediaPage.empty();

    final bool multi = type == null || type.isPerson;
    final String path = multi ? '/search/multi' : '/search/${type.apiValue}';

    final PaginatedJson result = await _client.getPaginated(
      path,
      query: <String, dynamic>{
        'query': trimmed,
        'page': page,
        'include_adult': false,
      },
      cancelToken: _token,
    );

    final List<MediaItem> items = MediaMapper.items(
      result.results,
      fallbackType: type ?? MediaType.movie,
      excludeAdult: true,
    );

    // En búsqueda multi TMDB mezcla películas y series por relevancia; se
    // mantiene ese orden porque es el que el usuario espera.
    return MediaPage(
      items: items,
      page: result.page,
      hasMore: result.hasMore,
      totalResults: result.totalResults,
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Detalle
  // ══════════════════════════════════════════════════════════════════════

  @override
  Future<MediaDetails> getDetails(int id, MediaType type) async {
    final MediaType resolved = type.isPerson ? MediaType.movie : type;
    final Map<String, dynamic> json = await _client.getObject(
      '/${resolved.apiValue}/$id',
      query: <String, dynamic>{
        'append_to_response': 'credits,videos,similar,recommendations,keywords',
      },
      cancelToken: _token,
    );
    return MediaMapper.details(json, type: resolved);
  }

  @override
  Future<List<Episode>> getSeasonEpisodes(
    int seriesId,
    int seasonNumber,
  ) async {
    final Map<String, dynamic> json = await _client.getObject(
      '/tv/$seriesId/season/$seasonNumber',
      cancelToken: _token,
    );
    return MediaMapper.episodes(json);
  }

  @override
  Future<List<Genre>> getGenres(MediaType type) async {
    final MediaType resolved = type.isPerson ? MediaType.movie : type;
    final List<Genre>? cached = _genreCache[resolved];
    if (cached != null) return cached;

    final List<Map<String, dynamic>> raw = await _client.getList(
      '/genre/${resolved.apiValue}/list',
      cancelToken: _token,
    );
    final List<Genre> genres = MediaMapper.genres(<String, dynamic>{
      'genres': raw,
    }).toList(growable: false);
    _genreCache[resolved] = genres;
    return genres;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Internos
  // ══════════════════════════════════════════════════════════════════════

  Future<MediaPage> _paged(String path, MediaType type, {int page = 1}) async {
    final PaginatedJson result = await _client.getPaginated(
      path,
      query: <String, dynamic>{'page': page},
      cancelToken: _token,
    );
    return MediaPage(
      items: MediaMapper.items(
        result.results,
        fallbackType: type,
        excludeAdult: true,
      ),
      page: result.page,
      hasMore: result.hasMore,
      totalResults: result.totalResults,
    );
  }

  CancelToken get _token => _cancelToken;

  @override
  void dispose() {
    if (!_cancelToken.isCancelled) {
      _cancelToken.cancel('Repositorio de catálogo descartado');
    }
    _client.close();
    _genreCache.clear();
  }
}
