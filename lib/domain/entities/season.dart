import 'package:equatable/equatable.dart';

/// Episodio de una temporada.
class Episode extends Equatable {
  const Episode({
    required this.number,
    required this.name,
    required this.overview,
    this.seasonNumber = 1,
    this.airDate,
    this.stillPath,
    this.voteAverage = 0,
    this.runtime,
  });

  final int number;
  final int seasonNumber;
  final String name;
  final String overview;
  final DateTime? airDate;
  final String? stillPath;
  final double voteAverage;
  final int? runtime;

  /// `1x03` — convención habitual para identificar un episodio.
  String get shortCode =>
      '${seasonNumber}x${number.toString().padLeft(2, '0')}';

  bool get hasStill => stillPath != null && stillPath!.isNotEmpty;

  @override
  List<Object?> get props => <Object?>[
    number,
    seasonNumber,
    name,
    overview,
    airDate,
    stillPath,
    voteAverage,
    runtime,
  ];
}

/// Temporada de una serie.
class Season extends Equatable {
  const Season({
    required this.id,
    required this.number,
    required this.name,
    required this.overview,
    this.posterPath,
    this.episodeCount = 0,
    this.airDate,
  });

  final int id;
  final int number;
  final String name;
  final String overview;
  final String? posterPath;
  final int episodeCount;
  final DateTime? airDate;

  /// Las «especiales» (temporada 0) no suelen interesar en la lista principal.
  bool get isSpecial => number == 0;

  bool get hasPoster => posterPath != null && posterPath!.isNotEmpty;

  bool get hasEpisodes => episodeCount > 0;

  @override
  List<Object?> get props => <Object?>[
    id,
    number,
    name,
    overview,
    posterPath,
    episodeCount,
    airDate,
  ];
}
