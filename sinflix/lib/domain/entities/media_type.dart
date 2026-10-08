/// Tipo de contenido. Unifica películas y series en una sola entidad para que
/// la UI (carruseles, rejillas, detalle) no tenga que duplicarse.
enum MediaType {
  movie('movie', 'Película', 'Películas'),
  tv('tv', 'Serie', 'Series'),

  /// Solo aparece en búsquedas multi y en tendencias globales.
  person('person', 'Persona', 'Personas');

  const MediaType(this.apiValue, this.label, this.pluralLabel);

  /// Valor que usa TMDB en `media_type` y en las rutas de la API.
  final String apiValue;

  /// Etiqueta en singular para la interfaz.
  final String label;

  /// Etiqueta en plural para la interfaz.
  final String pluralLabel;

  bool get isMovie => this == MediaType.movie;
  bool get isTv => this == MediaType.tv;
  bool get isPerson => this == MediaType.person;

  /// Convierte el valor de la API a [MediaType]. Devuelve `null` si es
  /// desconocido, para poder filtrar entradas raras sin romper el listado.
  static MediaType? tryParse(String? raw) {
    if (raw == null) return null;
    final String value = raw.trim().toLowerCase();
    for (final MediaType type in MediaType.values) {
      if (type.apiValue == value) return type;
    }
    return null;
  }

  /// Igual que [tryParse] pero con valor por defecto (película).
  static MediaType parse(String? raw, {MediaType fallback = MediaType.movie}) =>
      tryParse(raw) ?? fallback;
}
