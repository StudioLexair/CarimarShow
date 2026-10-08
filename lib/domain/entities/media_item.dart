import 'package:equatable/equatable.dart';

import 'media_type.dart';

/// Elemento de catálogo ligero: lo que devuelve cualquier listado de TMDB
/// (tendencias, populares, búsqueda, similares…).
///
/// Es la unidad que recorre toda la UI de listas. El detalle completo vive en
/// `MediaDetails`, que se pide solo al abrir la ficha.
class MediaItem extends Equatable {
  const MediaItem({
    required this.id,
    required this.type,
    required this.title,
    required this.overview,
    this.originalTitle,
    this.posterPath,
    this.backdropPath,
    this.voteAverage = 0,
    this.voteCount = 0,
    this.releaseDate,
    this.genreIds = const <int>[],
    this.originalLanguage,
    this.popularity = 0,
    this.adult = false,
  });

  /// Identificador de TMDB. Único **dentro de su tipo**: película y serie
  /// pueden compartir el mismo número, por eso [uniqueKey] incluye el tipo.
  final int id;

  final MediaType type;
  final String title;
  final String? originalTitle;
  final String overview;

  /// Rutas relativas del CDN, p. ej. `/8s4h9friP6Ci31RGF3XW9fC4XO.jpg`.
  final String? posterPath;
  final String? backdropPath;

  final double voteAverage;
  final int voteCount;
  final DateTime? releaseDate;
  final List<int> genreIds;
  final String? originalLanguage;
  final double popularity;
  final bool adult;

  /// Clave globalmente única para este título. Úsala en maps y en la lista.
  String get uniqueKey => '${type.apiValue}:$id';

  bool get hasPoster => posterPath != null && posterPath!.isNotEmpty;
  bool get hasBackdrop => backdropPath != null && backdropPath!.isNotEmpty;
  bool get hasOverview => overview.trim().isNotEmpty;
  bool get hasVote => voteAverage > 0;

  /// Año de estreno, o `null` si TMDB no lo aporta.
  int? get year => releaseDate?.year;

  /// Título alternativo cuando falta el localizado.
  String get displayTitle =>
      title.isNotEmpty ? title : (originalTitle ?? 'Sin título');

  @override
  List<Object?> get props => <Object?>[
    id,
    type,
    title,
    originalTitle,
    overview,
    posterPath,
    backdropPath,
    voteAverage,
    voteCount,
    releaseDate,
    genreIds,
    originalLanguage,
    popularity,
    adult,
  ];
}
