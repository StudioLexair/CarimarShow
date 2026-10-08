import 'package:equatable/equatable.dart';

/// Vídeo asociado a un título (tráiler, teaser, cómo se hizo…).
class MediaVideo extends Equatable {
  const MediaVideo({
    required this.id,
    required this.key,
    required this.name,
    required this.site,
    required this.type,
    this.official = true,
    this.publishedAt,
  });

  final String id;

  /// Identificador dentro del sitio. En YouTube es el `v=` de la URL.
  final String key;

  final String name;

  /// `YouTube`, `Vimeo`…
  final String site;

  /// `Trailer`, `Teaser`, `Clip`, `Behind the Scenes`…
  final String type;

  final bool official;
  final DateTime? publishedAt;

  bool get isYoutube => site.toLowerCase() == 'youtube';

  /// `true` para tráilers y teasers, que es lo que el usuario espera ver.
  bool get isPromo =>
      type.toLowerCase() == 'trailer' || type.toLowerCase() == 'teaser';

  /// URL para abrir en el navegador o en el reproductor embebido.
  String get watchUrl => isYoutube
      ? 'https://www.youtube.com/watch?v=$key'
      : 'https://www.themoviedb.org/video/$id';

  /// Miniatura de YouTube, si es el caso.
  String? get thumbnailUrl =>
      isYoutube ? 'https://img.youtube.com/vi/$key/hqdefault.jpg' : null;

  @override
  List<Object?> get props => <Object?>[
    id,
    key,
    name,
    site,
    type,
    official,
    publishedAt,
  ];
}

/// Selecciona el mejor vídeo para el botón «Ver tráiler».
///
/// Prioridad: tráiler oficial > tráiler > teaser oficial > teaser > cualquiera.
/// Devuelve `null` si la lista está vacía.
MediaVideo? pickBestTrailer(List<MediaVideo> videos) {
  if (videos.isEmpty) return null;

  int score(MediaVideo v) {
    final String type = v.type.toLowerCase();
    final bool official = v.official;
    return switch (type) {
      'trailer' => official ? 100 : 80,
      'teaser' => official ? 60 : 45,
      'clip' => official ? 25 : 20,
      _ => official ? 10 : 5,
    };
  }

  final List<MediaVideo> candidates = videos
      .where((MediaVideo v) => v.watchUrl.isNotEmpty)
      .toList();
  if (candidates.isEmpty) return null;

  candidates.sort((MediaVideo a, MediaVideo b) {
    final int byScore = score(b).compareTo(score(a));
    if (byScore != 0) return byScore;
    // A igual puntuación, el más reciente gana.
    final DateTime? da = a.publishedAt;
    final DateTime? db = b.publishedAt;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  });

  return candidates.first;
}
