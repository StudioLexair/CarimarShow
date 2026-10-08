import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/errors/app_exception.dart';
import '../../domain/entities/genre.dart';
import '../../domain/entities/media_details.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/media_type.dart';
import '../../domain/entities/season.dart';
import '../../domain/repositories/media_repository.dart';
import '../mappers/json_utils.dart';
import '../mappers/media_mapper.dart';

/// Catálogo local de respaldo.
///
/// Permite que CarimarShow arranque y se pueda explorar **sin ninguna credencial**:
/// ni token de TMDB ni backend. Sirve un conjunto de títulos ficticios incluidos
/// en `assets/data/demo_catalog.json`.
///
/// El JSON usa deliberadamente los mismos nombres de campo que TMDB, así todo
/// pasa por [MediaMapper] y la UI no distingue entre datos reales y de demo.
/// Cuando el usuario configure `TMDB_READ_TOKEN`, esta clase deja de usarse.
class DemoMediaSource implements MediaRepository {
  DemoMediaSource({this.assetPath = defaultAssetPath});

  static const String defaultAssetPath = 'assets/data/demo_catalog.json';

  final String assetPath;

  Map<String, dynamic>? _cache;

  @override
  bool get isLive => false;

  /// Carga (una sola vez) el catálogo empaquetado.
  Future<Map<String, dynamic>> _load() async {
    final Map<String, dynamic>? cached = _cache;
    if (cached != null) return cached;
    try {
      final String raw = await rootBundle.loadString(assetPath);
      final Map<String, dynamic> decoded = decodeJson(raw);
      return _cache = decoded;
    } on ParsingException {
      rethrow;
    } catch (error, stackTrace) {
      throw ParsingException(
        message: 'No se pudo cargar el catálogo de demostración',
        detail: '$assetPath → $error',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> _raw(MediaType type) async {
    final Map<String, dynamic> data = await _load();
    final String key = type.isTv ? 'series' : 'movies';
    return Json.list(data, key);
  }

  /// Extrae el bloque `_demo`, que contiene los campos de ficha completa.
  static Map<String, dynamic> _extras(Map<String, dynamic> raw) =>
      Json.objOrEmpty(raw, '_demo');

  // ══════════════════════════════════════════════════════════════════════
  //  Listados
  // ══════════════════════════════════════════════════════════════════════

  @override
  Future<List<MediaItem>> getTrending({
    MediaType type = MediaType.movie,
    String timeWindow = 'week',
    int limit = 20,
  }) async {
    final List<Map<String, dynamic>> source = <Map<String, dynamic>>[
      ...await _raw(MediaType.movie),
      ...await _raw(MediaType.tv),
    ]..sort(_byPopularity);
    return MediaMapper.items(source.take(limit * 2).toList(), limit: limit);
  }

  @override
  Future<MediaPage> getPopular(MediaType type, {int page = 1}) async {
    final List<Map<String, dynamic>> source = await _raw(type);
    source.sort(_byPopularity);
    return _page(source, type, page);
  }

  @override
  Future<MediaPage> getTopRated(MediaType type, {int page = 1}) async {
    final List<Map<String, dynamic>> source = await _raw(type);
    source.sort(
      (Map<String, dynamic> a, Map<String, dynamic> b) => Json.doubleOr(
        b,
        'vote_average',
        0,
      ).compareTo(Json.doubleOr(a, 'vote_average', 0)),
    );
    return _page(source, type, page);
  }

  @override
  Future<MediaPage> getUpcomingOrOnTheAir(
    MediaType type, {
    int page = 1,
  }) async {
    final DateTime now = DateTime.now();
    final String dateKey = type.isTv ? 'first_air_date' : 'release_date';
    final List<Map<String, dynamic>> source = await _raw(type);
    final List<Map<String, dynamic>> future = source.where((
      Map<String, dynamic> m,
    ) {
      final DateTime? date = Json.parseDate(Json.strOrNull(m, dateKey));
      return date != null && date.isAfter(now);
    }).toList();
    // Si no hay títulos futuros en el catálogo de demo, se muestran los más
    // recientes: mejor una lista útil que una pantalla vacía.
    final List<Map<String, dynamic>> effective = future.isEmpty
        ? source
        : future;
    effective.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final DateTime? da = Json.parseDate(Json.strOrNull(a, dateKey));
      final DateTime? db = Json.parseDate(Json.strOrNull(b, dateKey));
      if (da == null || db == null) return 0;
      return db.compareTo(da);
    });
    return _page(effective, type, page);
  }

  @override
  Future<MediaPage> getNowPlaying({int page = 1}) =>
      getUpcomingOrOnTheAir(MediaType.movie, page: page);

  @override
  Future<MediaPage> discover(DiscoverQuery query) async {
    final List<Map<String, dynamic>> source = await _raw(query.type);

    Iterable<Map<String, dynamic>> filtered = source;

    if (query.genreIds.isNotEmpty) {
      filtered = filtered.where((Map<String, dynamic> m) {
        final List<int> ids = Json.intList(m, 'genre_ids');
        return ids.any(query.genreIds.contains);
      });
    }
    if (query.minVoteAverage != null && query.minVoteAverage! > 0) {
      filtered = filtered.where(
        (Map<String, dynamic> m) =>
            Json.doubleOr(m, 'vote_average', 0) >= query.minVoteAverage!,
      );
    }
    if (query.year != null) {
      final String dateKey = query.type.isTv
          ? 'first_air_date'
          : 'release_date';
      filtered = filtered.where(
        (Map<String, dynamic> m) =>
            Json.parseDate(Json.strOrNull(m, dateKey))?.year == query.year,
      );
    }
    if (!query.includeAdult) {
      filtered = filtered.where(
        (Map<String, dynamic> m) => !Json.boolOr(m, 'adult', false),
      );
    }

    final List<Map<String, dynamic>> list = filtered.toList()
      ..sort(_sortFor(query.sortBy));
    return _page(list, query.type, query.page);
  }

  @override
  Future<MediaPage> search(
    String query, {
    MediaType? type,
    int page = 1,
  }) async {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const MediaPage.empty();

    final List<Map<String, dynamic>> pool = <Map<String, dynamic>>[
      if (type == null || type.isMovie) ...await _raw(MediaType.movie),
      if (type == null || type.isTv) ...await _raw(MediaType.tv),
    ];

    final List<Map<String, dynamic>> matches =
        pool.where((Map<String, dynamic> m) {
          final String title = (Json.str(
            m,
            'title',
            fallback: Json.str(m, 'name'),
          )).toLowerCase();
          final String overview = Json.str(m, 'overview').toLowerCase();
          return title.contains(needle) || overview.contains(needle);
        }).toList()..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
          final String ta = (Json.str(
            a,
            'title',
            fallback: Json.str(a, 'name'),
          )).toLowerCase();
          final String tb = (Json.str(
            b,
            'title',
            fallback: Json.str(b, 'name'),
          )).toLowerCase();
          final bool aStarts = ta.startsWith(needle);
          final bool bStarts = tb.startsWith(needle);
          if (aStarts != bStarts) return aStarts ? -1 : 1;
          return _byPopularity(b, a);
        });

    return _page(matches, type ?? MediaType.movie, page);
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Detalle
  // ══════════════════════════════════════════════════════════════════════

  @override
  Future<MediaDetails> getDetails(int id, MediaType type) async {
    final Map<String, dynamic>? raw = await _findById(id, type);
    if (raw == null) {
      throw NotFoundException(
        detail: 'Título $id (${type.apiValue}) no presente en el catálogo demo',
      );
    }
    // Se fusionan los campos de listado con los de ficha completa, imitando la
    // respuesta plana que produce `append_to_response` en TMDB.
    final List<Map<String, dynamic>> pool = <Map<String, dynamic>>[
      ...await _raw(type),
      ...await _raw(type.isTv ? MediaType.movie : MediaType.tv),
    ];
    final Map<String, dynamic> related = _related(raw, pool);
    final Map<String, dynamic> merged = <String, dynamic>{
      ...raw,
      ..._extras(raw),
      'similar': related,
      'recommendations': related,
    };
    return MediaMapper.details(merged, type: type);
  }

  @override
  Future<List<Episode>> getSeasonEpisodes(
    int seriesId,
    int seasonNumber,
  ) async {
    final Map<String, dynamic>? raw = await _findById(seriesId, MediaType.tv);
    if (raw == null) {
      throw NotFoundException(
        detail: 'Serie $seriesId no presente en el catálogo demo',
      );
    }
    final List<Season> seasons = MediaMapper.seasons(_extras(raw));
    final Season? season = seasons
        .where((Season s) => s.number == seasonNumber)
        .firstOrNull;
    final int count = season?.episodeCount ?? 0;
    if (count <= 0) return const <Episode>[];

    final List<int> runtimes = Json.intList(_extras(raw), 'episode_run_time');
    final int runtime = runtimes.isEmpty ? 45 : runtimes.first;

    return List<Episode>.generate(
      count,
      (int index) => Episode(
        number: index + 1,
        seasonNumber: seasonNumber,
        name: 'Episodio ${index + 1}',
        overview: 'Episodio de demostración generado localmente.',
        runtime: runtime,
      ),
    );
  }

  @override
  Future<List<Genre>> getGenres(MediaType type) async {
    final Map<String, dynamic> data = await _load();
    final String key = type.isTv ? 'genres_tv' : 'genres_movie';
    return Json.mapListLenient<Genre>(Json.list(data, key), (
      Map<String, dynamic> g,
    ) {
      final int id = Json.intOr(g, 'id', 0);
      final String name = Json.str(g, 'name');
      return id > 0 && name.isEmpty ? null : Genre(id: id, name: name);
    });
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Internos
  // ══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> _findById(int id, MediaType type) async {
    final List<Map<String, dynamic>> source = await _raw(type);
    for (final Map<String, dynamic> entry in source) {
      if (Json.intOr(entry, 'id', -1) == id) return entry;
    }
    // Búsqueda cruzada: el id puede pertenecer al otro tipo.
    final List<Map<String, dynamic>> other = await _raw(
      type.isTv ? MediaType.movie : MediaType.tv,
    );
    for (final Map<String, dynamic> entry in other) {
      if (Json.intOr(entry, 'id', -1) == id) return entry;
    }
    return null;
  }

  /// Bloque de títulos parecidos, con la misma forma que la respuesta de TMDB.
  ///
  /// Ordena por solapamiento de géneros y, a igualdad, por popularidad.
  static Map<String, dynamic> _related(
    Map<String, dynamic> raw,
    List<Map<String, dynamic>> pool,
  ) {
    final int ownId = Json.intOr(raw, 'id', -1);
    final List<int> ownGenres = Json.intList(raw, 'genre_ids');

    final List<Map<String, dynamic>> scored =
        pool
            .where((Map<String, dynamic> m) => Json.intOr(m, 'id', -1) != ownId)
            .toList()
          ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
            final int overlapA = Json.intList(
              a,
              'genre_ids',
            ).where(ownGenres.contains).length;
            final int overlapB = Json.intList(
              b,
              'genre_ids',
            ).where(ownGenres.contains).length;
            if (overlapA != overlapB) return overlapB.compareTo(overlapA);
            return _byPopularity(b, a);
          });

    final List<Map<String, dynamic>> results = scored
        .take(10)
        .map(_slim)
        .toList(growable: false);
    return <String, dynamic>{
      'page': 1,
      'results': results,
      'total_pages': 1,
      'total_results': results.length,
    };
  }

  /// Copia solo los campos que corresponden a un elemento de listado.
  static Map<String, dynamic> _slim(Map<String, dynamic> m) =>
      <String, dynamic>{
        for (final String key in const <String>[
          'id',
          'title',
          'name',
          'original_title',
          'original_name',
          'overview',
          'poster_path',
          'backdrop_path',
          'vote_average',
          'vote_count',
          'release_date',
          'first_air_date',
          'genre_ids',
          'popularity',
          'media_type',
          'adult',
        ])
          if (m.containsKey(key)) key: m[key],
      };

  MediaPage _page(List<Map<String, dynamic>> source, MediaType type, int page) {
    const int pageSize = 12;
    final int start = (page - 1) * pageSize;
    if (start >= source.length) {
      return MediaPage(
        items: const <MediaItem>[],
        page: page,
        hasMore: false,
        totalResults: source.length,
      );
    }
    final int end = (start + pageSize).clamp(0, source.length);
    return MediaPage(
      items: MediaMapper.items(source.sublist(start, end), fallbackType: type),
      page: page,
      hasMore: end < source.length,
      totalResults: source.length,
    );
  }

  static int _byPopularity(Map<String, dynamic> a, Map<String, dynamic> b) =>
      Json.doubleOr(
        b,
        'popularity',
        0,
      ).compareTo(Json.doubleOr(a, 'popularity', 0));

  static int Function(Map<String, dynamic>, Map<String, dynamic>) _sortFor(
    String sortBy,
  ) {
    return switch (sortBy) {
      'vote_average.desc' =>
        (Map<String, dynamic> a, Map<String, dynamic> b) => Json.doubleOr(
          b,
          'vote_average',
          0,
        ).compareTo(Json.doubleOr(a, 'vote_average', 0)),
      'vote_average.asc' =>
        (Map<String, dynamic> a, Map<String, dynamic> b) => Json.doubleOr(
          a,
          'vote_average',
          0,
        ).compareTo(Json.doubleOr(b, 'vote_average', 0)),
      'release_date.desc' || 'first_air_date.desc' =>
        (Map<String, dynamic> a, Map<String, dynamic> b) {
          final DateTime? da = Json.parseDate(
            Json.strOrNull(a, 'release_date') ??
                Json.strOrNull(a, 'first_air_date'),
          );
          final DateTime? db = Json.parseDate(
            Json.strOrNull(b, 'release_date') ??
                Json.strOrNull(b, 'first_air_date'),
          );
          if (da == null || db == null) return 0;
          return db.compareTo(da);
        },
      'title.asc' =>
        (Map<String, dynamic> a, Map<String, dynamic> b) => Json.str(
          a,
          'title',
          fallback: Json.str(a, 'name'),
        ).compareTo(Json.str(b, 'title', fallback: Json.str(b, 'name'))),
      _ => _byPopularity,
    };
  }

  @override
  void dispose() => _cache = null;
}

/// Descodifica JSON validando que la raíz sea un objeto.
Map<String, dynamic> decodeJson(String source) {
  final dynamic parsed = jsonDecode(source);
  if (parsed is! Map<String, dynamic>) {
    throw const ParsingException(
      detail: 'El catálogo demo debe ser un objeto JSON en la raíz',
    );
  }
  return parsed;
}
