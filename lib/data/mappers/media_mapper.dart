import '../../core/errors/app_exception.dart';
import '../../domain/entities/cast_member.dart';
import '../../domain/entities/genre.dart';
import '../../domain/entities/media_details.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/media_type.dart';
import '../../domain/entities/media_video.dart';
import '../../domain/entities/season.dart';
import 'json_utils.dart';

/// Traducción del JSON de TMDB a entidades de dominio.
///
/// Todo el conocimiento del formato de TMDB vive aquí. Si mañana se cambia de
/// proveedor de datos, solo hay que reescribir esta clase.
abstract final class MediaMapper {
  MediaMapper._();

  // ══════════════════════════════════════════════════════════════════════
  //  MediaItem (listados)
  // ══════════════════════════════════════════════════════════════════════

  /// Convierte un elemento de listado.
  ///
  /// [fallbackType] se usa cuando la respuesta no trae `media_type` (endpoints
  /// que son siempre de películas o siempre de series).
  ///
  /// Devuelve `null` si el elemento no tiene identificador válido o si es una
  /// persona, que no se representa como [MediaItem].
  static MediaItem? itemOrNull(
    Map<String, dynamic> json, {
    MediaType fallbackType = MediaType.movie,
  }) {
    final int id = Json.intOr(json, 'id', 0);
    if (id <= 0) return null;

    final MediaType type =
        MediaType.tryParse(Json.strOrNull(json, 'media_type')) ?? fallbackType;
    if (type.isPerson) return null;

    // Películas usan `title`; series usan `name`.
    final String title = Json.str(
      json,
      'title',
      fallback: Json.str(json, 'name'),
    );
    final String originalTitle = Json.str(
      json,
      'original_title',
      fallback: Json.str(json, 'original_name'),
    );

    // Ídem con las fechas de estreno.
    final DateTime? releaseDate =
        Json.dateOrNull(json, 'release_date') ??
        Json.dateOrNull(json, 'first_air_date');

    return MediaItem(
      id: id,
      type: type,
      title: title,
      originalTitle: originalTitle.isEmpty ? null : originalTitle,
      overview: Json.str(json, 'overview'),
      posterPath: Json.strOrNull(json, 'poster_path'),
      backdropPath: Json.strOrNull(json, 'backdrop_path'),
      voteAverage: Json.doubleOr(json, 'vote_average', 0),
      voteCount: Json.intOr(json, 'vote_count', 0),
      releaseDate: releaseDate,
      genreIds: Json.intList(json, 'genre_ids'),
      originalLanguage: Json.strOrNull(json, 'original_language'),
      popularity: Json.doubleOr(json, 'popularity', 0),
      adult: Json.boolOr(json, 'adult', false),
    );
  }

  /// Igual que [itemOrNull] pero lanza si el elemento es inválido.
  static MediaItem item(
    Map<String, dynamic> json, {
    MediaType fallbackType = MediaType.movie,
  }) {
    final MediaItem? result = itemOrNull(json, fallbackType: fallbackType);
    if (result == null) {
      throw ParsingException(
        detail:
            'Elemento de catálogo sin id válido o de tipo no soportado: '
            '${json.keys.take(8).join(', ')}',
      );
    }
    return result;
  }

  /// Mapea una lista completa, descartando entradas inválidas o personas.
  static List<MediaItem> items(
    List<Map<String, dynamic>> list, {
    MediaType fallbackType = MediaType.movie,
    bool excludeAdult = false,
    int? limit,
  }) {
    Iterable<MediaItem> mapped = Json.mapListLenient<MediaItem>(
      list,
      (Map<String, dynamic> json) =>
          itemOrNull(json, fallbackType: fallbackType),
    );
    if (excludeAdult) {
      mapped = mapped.where((MediaItem m) => !m.adult);
    }
    final List<MediaItem> result = mapped.toList(growable: false);
    if (limit != null && limit > 0 && result.length > limit) {
      return result.sublist(0, limit);
    }
    return result;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Género
  // ══════════════════════════════════════════════════════════════════════

  static Genre genre(Map<String, dynamic> json) =>
      Genre(id: Json.intOr(json, 'id', 0), name: Json.str(json, 'name'));

  static List<Genre> genres(
    Map<String, dynamic> json, [
    String key = 'genres',
  ]) => Json.mapListLenient<Genre>(Json.list(json, key), (
    Map<String, dynamic> g,
  ) {
    final int id = Json.intOr(g, 'id', 0);
    final String name = Json.str(g, 'name');
    return id > 0 && name.isNotEmpty ? genre(g) : null;
  });

  // ══════════════════════════════════════════════════════════════════════
  //  Reparto y equipo
  // ══════════════════════════════════════════════════════════════════════

  static CastMember cast(Map<String, dynamic> json, {int fallbackOrder = 0}) =>
      CastMember(
        id: Json.intOr(json, 'id', 0),
        name: Json.str(json, 'name'),
        character: Json.str(json, 'character'),
        profilePath: Json.strOrNull(json, 'profile_path'),
        order: Json.intOr(json, 'order', fallbackOrder),
        department: Json.strOrNull(json, 'department'),
        job: Json.strOrNull(json, 'job'),
      );

  static List<CastMember> castList(Map<String, dynamic> json) =>
      Json.mapListLenient<CastMember>(
        Json.list(Json.objOrEmpty(json, 'credits'), 'cast'),
        (Map<String, dynamic> c) {
          final String name = Json.str(c, 'name');
          return name.isEmpty ? null : cast(c, fallbackOrder: 999);
        },
      );

  static List<CastMember> crewList(Map<String, dynamic> json) =>
      Json.mapListLenient<CastMember>(
        Json.list(Json.objOrEmpty(json, 'credits'), 'crew'),
        (Map<String, dynamic> c) {
          final String name = Json.str(c, 'name');
          return name.isEmpty ? null : cast(c);
        },
      );

  // ══════════════════════════════════════════════════════════════════════
  //  Vídeos
  // ══════════════════════════════════════════════════════════════════════

  static MediaVideo? videoOrNull(Map<String, dynamic> json) {
    final String key = Json.str(json, 'key');
    final String site = Json.str(json, 'site');
    if (key.isEmpty) return null;
    return MediaVideo(
      id: Json.str(json, 'id'),
      key: key,
      name: Json.str(json, 'name'),
      site: site.isEmpty ? 'YouTube' : site,
      type: Json.str(json, 'type', fallback: 'Clip'),
      official: Json.boolOr(json, 'official', true),
      publishedAt: Json.dateOrNull(json, 'published_at'),
    );
  }

  static List<MediaVideo> videos(Map<String, dynamic> json) =>
      Json.mapListLenient<MediaVideo>(
        Json.list(Json.objOrEmpty(json, 'videos'), 'results'),
        videoOrNull,
      );

  // ══════════════════════════════════════════════════════════════════════
  //  Temporadas y episodios
  // ══════════════════════════════════════════════════════════════════════

  static Season? seasonOrNull(Map<String, dynamic> json) {
    final int id = Json.intOr(json, 'id', 0);
    if (id <= 0) return null;
    final int number = Json.intOr(json, 'season_number', 1);
    return Season(
      id: id,
      number: number,
      name: Json.str(
        json,
        'name',
        fallback: number == 0 ? 'Especiales' : 'Temporada $number',
      ),
      overview: Json.str(json, 'overview'),
      posterPath: Json.strOrNull(json, 'poster_path'),
      episodeCount: Json.intOr(json, 'episode_count', 0),
      airDate: Json.dateOrNull(json, 'air_date'),
    );
  }

  static List<Season> seasons(Map<String, dynamic> json) =>
      Json.mapListLenient<Season>(Json.list(json, 'seasons'), seasonOrNull);

  static Episode? episodeOrNull(Map<String, dynamic> json) {
    final int number = Json.intOr(json, 'episode_number', -1);
    if (number < 0) return null;
    return Episode(
      number: number,
      seasonNumber: Json.intOr(json, 'season_number', 1),
      name: Json.str(json, 'name'),
      overview: Json.str(json, 'overview'),
      airDate: Json.dateOrNull(json, 'air_date'),
      stillPath: Json.strOrNull(json, 'still_path'),
      voteAverage: Json.doubleOr(json, 'vote_average', 0),
      runtime: Json.intOrNull(json, 'runtime'),
    );
  }

  static List<Episode> episodes(Map<String, dynamic> json) =>
      Json.mapListLenient<Episode>(Json.list(json, 'episodes'), episodeOrNull);

  // ══════════════════════════════════════════════════════════════════════
  //  MediaDetails (ficha completa)
  // ══════════════════════════════════════════════════════════════════════

  /// Construye la ficha completa desde la respuesta de
  /// `/{type}/{id}?append_to_response=credits,videos,similar,recommendations`.
  static MediaDetails details(
    Map<String, dynamic> json, {
    required MediaType type,
  }) {
    final MediaItem base = item(json, fallbackType: type);
    final bool isTv = base.type.isTv;

    // Nombres de países e idiomas: TMDB da objetos con `name` / `english_name`.
    final List<String> countries = Json.list(json, 'production_countries')
        .map(
          (Map<String, dynamic> c) =>
              Json.str(c, 'name', fallback: Json.str(c, 'iso_3166_1')),
        )
        .where((String s) => s.isNotEmpty)
        .toList(growable: false);

    final List<String> languages = Json.list(json, 'spoken_languages')
        .map(
          (Map<String, dynamic> l) => Json.str(
            l,
            'english_name',
            fallback: Json.str(l, 'name', fallback: Json.str(l, 'iso_639_1')),
          ),
        )
        .where((String s) => s.isNotEmpty)
        .toList(growable: false);

    // `created_by` solo existe en series.
    final List<String> createdBy = isTv
        ? Json.list(json, 'created_by')
              .map((Map<String, dynamic> p) => Json.str(p, 'name'))
              .where((String s) => s.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    // Palabras clave: la estructura difiere entre película (`keywords`) y
    // serie (`results`).
    final Map<String, dynamic> keywordsRoot = Json.objOrEmpty(json, 'keywords');
    final List<Map<String, dynamic>> keywordList = isTv
        ? Json.list(keywordsRoot, 'results')
        : Json.list(keywordsRoot, 'keywords');
    final List<String> keywords = keywordList
        .map((Map<String, dynamic> k) => Json.str(k, 'name'))
        .where((String s) => s.isNotEmpty)
        .take(12)
        .toList(growable: false);

    final Map<String, dynamic>? nextEpisode = Json.objOrNull(
      json,
      'next_episode_to_air',
    );

    return MediaDetails(
      item: base,
      genres: genres(json),
      tagline: Json.strOrNull(json, 'tagline'),
      status: Json.strOrNull(json, 'status'),
      runtime: Json.intOrNull(json, 'runtime'),
      seasons: isTv ? seasons(json) : const <Season>[],
      episodeRuntimes: isTv
          ? Json.intList(json, 'episode_run_time')
          : const <int>[],
      numberOfSeasons: Json.intOrNull(json, 'number_of_seasons'),
      numberOfEpisodes: Json.intOrNull(json, 'number_of_episodes'),
      cast: castList(json),
      crew: crewList(json),
      videos: videos(json),
      // `append_to_response` anida estas listas bajo su propia clave `results`.
      similar: items(
        Json.list(Json.objOrEmpty(json, 'similar'), 'results'),
        fallbackType: base.type,
        limit: 20,
      ),
      recommendations: items(
        Json.list(Json.objOrEmpty(json, 'recommendations'), 'results'),
        fallbackType: base.type,
        limit: 20,
      ),
      productionCountries: countries,
      spokenLanguages: languages,
      budget: Json.intOrNull(json, 'budget'),
      revenue: Json.intOrNull(json, 'revenue'),
      imdbId: Json.strOrNull(json, 'imdb_id'),
      homepage: Json.strOrNull(json, 'homepage'),
      createdBy: createdBy,
      lastAirDate: Json.dateOrNull(json, 'last_air_date'),
      nextEpisodeToAir: nextEpisode == null ? null : episodeOrNull(nextEpisode),
      inProduction: isTv ? Json.boolOr(json, 'in_production', false) : null,
      keywords: keywords,
    );
  }
}
