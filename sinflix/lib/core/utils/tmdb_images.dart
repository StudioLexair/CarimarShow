import '../../core/constants/tmdb_constants.dart';

/// Construcción de URLs de imágenes del CDN de TMDB.
///
/// TMDB devuelve rutas relativas (`/abc123.jpg`) y hay que componerlas con el
/// tamaño adecuado. Pedir `original` para un póster de 120 px de ancho es el
/// error de rendimiento más común con esta API: son varios MB por imagen.
abstract final class TmdbImages {
  TmdbImages._();

  /// URL completa, o `null` si no hay imagen.
  static String? url(String? path, String size) {
    if (path == null) return null;
    final String trimmed = path.trim();
    if (trimmed.isEmpty) return null;
    // Ya viene una URL absoluta (p. ej. avatar de usuario): se usa tal cual.
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final String normalized = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '${Tmdb.imageBaseUrl}/$size$normalized';
  }

  static String? poster(
    String? path, {
    String size = TmdbImageSize.posterMedium,
  }) => url(path, size);

  static String? backdrop(
    String? path, {
    String size = TmdbImageSize.backdropLarge,
  }) => url(path, size);

  static String? profile(
    String? path, {
    String size = TmdbImageSize.profileMedium,
  }) => url(path, size);

  static String? still(
    String? path, {
    String size = TmdbImageSize.backdropMedium,
  }) => url(path, size);

  static String? logo(String? path, {String size = TmdbImageSize.logoLarge}) =>
      url(path, size);

  /// Póster en alta resolución para la ficha de detalle.
  static String? posterLarge(String? path) =>
      url(path, TmdbImageSize.posterLarge);

  /// Fondo en alta resolución para la cabecera de la ficha.
  static String? backdropLarge(String? path) =>
      url(path, TmdbImageSize.backdropOriginal);
}
