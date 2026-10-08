/// Constantes de la API de TMDB (v3).
///
/// Documentación: https://developer.themoviedb.org
abstract final class Tmdb {
  /// Raíz de la API v3.
  static const String baseUrl = 'https://api.themoviedb.org/3';

  /// CDN público de imágenes. No requiere autenticación.
  static const String imageBaseUrl = 'https://image.tmdb.org/t/p';

  /// Tiempo máximo razonable para una petición de catálogo.
  static const Duration timeout = Duration(seconds: 20);

  /// Tamaño de página que devuelve TMDB (fijo en 20).
  static const int pageSize = 20;
}

/// Tamaños de imagen disponibles en el CDN de TMDB.
///
/// Usar el tamaño correcto importa: `original` puede pesar varios MB y arruina
/// el rendimiento de una lista con decenas de pósters.
abstract final class TmdbImageSize {
  // Pósters
  static const String posterSmall = 'w154';
  static const String posterMedium = 'w342';
  static const String posterLarge = 'w500';
  static const String posterOriginal = 'original';

  // Fondos
  static const String backdropSmall = 'w300';
  static const String backdropMedium = 'w780';
  static const String backdropLarge = 'w1280';
  static const String backdropOriginal = 'original';

  // Retratos (reparto)
  static const String profileSmall = 'w45';
  static const String profileMedium = 'w185';
  static const String profileLarge = 'h632';

  // Logos
  static const String logoMedium = 'w185';
  static const String logoLarge = 'w500';
}

/// Ventana temporal de las listas de tendencias.
enum TmdbTimeWindow {
  day('day'),
  week('week');

  const TmdbTimeWindow(this.value);
  final String value;
}

/// Criterios de ordenación admitidos por `/discover`.
abstract final class TmdbSortBy {
  static const String popularityDesc = 'popularity.desc';
  static const String popularityAsc = 'popularity.asc';
  static const String voteAverageDesc = 'vote_average.desc';
  static const String voteAverageAsc = 'vote_average.asc';
  static const String releaseDateDesc = 'release_date.desc';
  static const String releaseDateAsc = 'release_date.asc';
  static const String revenueDesc = 'revenue.desc';
  static const String titleAsc = 'title.asc';

  static const List<String> all = <String>[
    popularityDesc,
    voteAverageDesc,
    releaseDateDesc,
    revenueDesc,
    titleAsc,
  ];

  /// Etiqueta legible para mostrar en la interfaz.
  static String label(String value) => switch (value) {
    popularityDesc => 'Popularidad',
    popularityAsc => 'Popularidad (menor)',
    voteAverageDesc => 'Mejor valoradas',
    voteAverageAsc => 'Peor valoradas',
    releaseDateDesc => 'Más recientes',
    releaseDateAsc => 'Más antiguas',
    revenueDesc => 'Recaudación',
    titleAsc => 'Título (A-Z)',
    _ => value,
  };
}

/// Identificadores de género de TMDB.
///
/// Se usan para las pestañas rápidas de la pantalla de descubrimiento. La lista
/// completa se obtiene en caliente con `/genre/{movie|tv}/list`.
abstract final class TmdbGenre {
  static const int action = 28;
  static const int adventure = 12;
  static const int animation = 16;
  static const int comedy = 35;
  static const int crime = 80;
  static const int documentary = 99;
  static const int drama = 18;
  static const int family = 10751;
  static const int fantasy = 14;
  static const int history = 36;
  static const int horror = 27;
  static const int music = 10402;
  static const int mystery = 9648;
  static const int romance = 10749;
  static const int scifi = 878;
  static const int thriller = 53;
  static const int war = 10752;
  static const int western = 37;
}
