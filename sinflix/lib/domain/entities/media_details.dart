import 'package:equatable/equatable.dart';

import 'cast_member.dart';
import 'genre.dart';
import 'media_item.dart';
import 'media_video.dart';
import 'season.dart';

/// Ficha completa de un título: todo lo que se muestra en la pantalla de detalle.
///
/// Se construye con una única petición a TMDB gracias a `append_to_response`,
/// que incluye créditos, vídeos, similares y recomendaciones en la misma llamada.
class MediaDetails extends Equatable {
  const MediaDetails({
    required this.item,
    required this.genres,
    this.tagline,
    this.status,
    this.runtime,
    this.seasons = const <Season>[],
    this.episodeRuntimes = const <int>[],
    this.numberOfSeasons,
    this.numberOfEpisodes,
    this.cast = const <CastMember>[],
    this.crew = const <CastMember>[],
    this.videos = const <MediaVideo>[],
    this.similar = const <MediaItem>[],
    this.recommendations = const <MediaItem>[],
    this.productionCountries = const <String>[],
    this.spokenLanguages = const <String>[],
    this.budget,
    this.revenue,
    this.imdbId,
    this.homepage,
    this.createdBy = const <String>[],
    this.lastAirDate,
    this.nextEpisodeToAir,
    this.inProduction,
    this.keywords = const <String>[],
  });

  /// Datos de listado, ya normalizados (título, póster, puntuación…).
  final MediaItem item;

  final List<Genre> genres;
  final String? tagline;
  final String? status;

  // ── Películas ────────────────────────────────────────────────────────
  final int? runtime;
  final int? budget;
  final int? revenue;

  // ── Series ───────────────────────────────────────────────────────────
  final List<Season> seasons;
  final List<int> episodeRuntimes;
  final int? numberOfSeasons;
  final int? numberOfEpisodes;
  final List<String> createdBy;
  final DateTime? lastAirDate;
  final Episode? nextEpisodeToAir;
  final bool? inProduction;

  // ── Comunes ──────────────────────────────────────────────────────────
  final List<CastMember> cast;
  final List<CastMember> crew;
  final List<MediaVideo> videos;
  final List<MediaItem> similar;
  final List<MediaItem> recommendations;
  final List<String> productionCountries;
  final List<String> spokenLanguages;
  final String? imdbId;
  final String? homepage;
  final List<String> keywords;

  int get id => item.id;

  String get title => item.displayTitle;

  bool get hasTagline => tagline != null && tagline!.trim().isNotEmpty;

  /// Tráiler recomendado para el botón principal, si existe.
  MediaVideo? get trailer => pickBestTrailer(videos);

  bool get hasTrailer => trailer != null;

  /// Temporadas «reales», excluyendo las especiales (temporada 0).
  List<Season> get regularSeasons =>
      seasons.where((Season s) => !s.isSpecial).toList(growable: false);

  /// Reparto limitado para el carrusel horizontal.
  List<CastMember> get topCast =>
      cast.length <= 20 ? cast : cast.sublist(0, 20);

  /// Directores principales, extraídos del equipo técnico.
  List<String> get directors => crew
      .where(
        (CastMember c) =>
            (c.job ?? '').toLowerCase() == 'director' ||
            (c.department ?? '').toLowerCase() == 'directing',
      )
      .map((CastMember c) => c.name)
      .where((String n) => n.isNotEmpty)
      .toSet()
      .take(3)
      .toList(growable: false);

  /// Nombres de género, para la línea de metadatos.
  List<String> get genreNames =>
      genres.map((Genre g) => g.name).toList(growable: false);

  /// Enlaces de la ficha en portales externos.
  String get tmdbUrl => item.type.isTv
      ? 'https://www.themoviedb.org/tv/$id'
      : 'https://www.themoviedb.org/movie/$id';

  String get imdbUrl => (imdbId == null || imdbId!.isEmpty)
      ? tmdbUrl
      : 'https://www.imdb.com/title/$imdbId/';

  @override
  List<Object?> get props => <Object?>[
    item,
    genres,
    tagline,
    status,
    runtime,
    seasons,
    episodeRuntimes,
    numberOfSeasons,
    numberOfEpisodes,
    cast,
    crew,
    videos,
    similar,
    recommendations,
    productionCountries,
    spokenLanguages,
    imdbId,
    homepage,
    createdBy,
    lastAirDate,
    nextEpisodeToAir,
    inProduction,
    keywords,
  ];
}
