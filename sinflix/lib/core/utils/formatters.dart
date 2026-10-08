import 'package:intl/intl.dart';

/// Formateo de fechas, duraciones y puntuaciones.
///
/// Todas las funciones son tolerantes a entradas nulas o vacías: devuelven una
/// cadena de reserva en lugar de lanzar, porque TMDB omite campos con frecuencia
/// (títulos sin fecha de estreno, series en producción sin número de episodios…).
abstract final class Formatters {
  Formatters._();

  static final NumberFormat _voteFormat = NumberFormat('0.0');
  static final NumberFormat _compactNumber = NumberFormat.compact(locale: 'es');

  /// `2008-07-16T12:00:00.000Z` → [DateTime] (o `null`).
  static DateTime? parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  /// Año de una fecha, o `''` si no existe. Es lo más útil en pósters y listas.
  static String year(DateTime? date) => date == null ? '' : '${date.year}';

  /// Fecha legible en español: `16 de julio de 2008`.
  static String longDate(DateTime? date) {
    if (date == null) return '—';
    return DateFormat.yMMMMd('es').format(date);
  }

  /// Fecha corta: `16 jul 2008`.
  static String shortDate(DateTime? date) {
    if (date == null) return '—';
    return DateFormat('d MMM y', 'es').format(date);
  }

  /// Puntuación con un decimal: `8.5`. Devuelve `''` si es 0 o nula.
  static String vote(double? value) {
    if (value == null || value <= 0) return '';
    return _voteFormat.format(value.clamp(0, 10));
  }

  /// Puntuación como porcentaje redondeado: `85%`.
  static String votePercent(double? value) {
    if (value == null || value <= 0) return '';
    return '${(value.clamp(0, 10) * 10).round()}%';
  }

  /// Recuento de votos compacto: `30,4 mil`.
  static String voteCount(int? count) {
    if (count == null || count <= 0) return '';
    return _compactNumber.format(count);
  }

  /// Minutos → `2 h 32 min` (o `48 min` si es menos de una hora).
  static String runtime(int? minutes) {
    if (minutes == null || minutes <= 0) return '—';
    final int hours = minutes ~/ 60;
    final int mins = minutes % 60;
    if (hours == 0) return '$mins min';
    if (mins == 0) return '$hours h';
    return '$hours h $mins min';
  }

  /// Lista de duraciones de episodios → `25–45 min`.
  static String episodeRuntime(List<int>? runtimes) {
    if (runtimes == null || runtimes.isEmpty) return '—';
    final List<int> valid = runtimes.where((int m) => m > 0).toList()..sort();
    if (valid.isEmpty) return '—';
    if (valid.length == 1 || valid.first == valid.last) {
      return '${valid.first} min';
    }
    return '${valid.first}–${valid.last} min';
  }

  /// `en` → `Inglés`, `es` → `Español`. Mapa corto; el resto se muestra tal cual.
  static String languageName(String? isoCode) {
    if (isoCode == null || isoCode.isEmpty) return '—';
    return _languages[isoCode.toLowerCase()] ?? isoCode.toUpperCase();
  }

  /// Une textos no vacíos con un separador, ignorando nulos.
  static String join(Iterable<String?> parts, {String separator = ' · '}) =>
      parts
          .where((String? p) => p != null && p.trim().isNotEmpty)
          .map((String? p) => p!.trim())
          .join(separator);

  /// Recorta con puntos suspensivos sin cortar a mitad de palabra.
  static String ellipsis(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    final String cut = text.substring(0, maxLength);
    final int lastSpace = cut.lastIndexOf(' ');
    return '${lastSpace > maxLength * 0.6 ? cut.substring(0, lastSpace) : cut}…';
  }

  static const Map<String, String> _languages = <String, String>{
    'en': 'Inglés',
    'es': 'Español',
    'fr': 'Francés',
    'de': 'Alemán',
    'it': 'Italiano',
    'pt': 'Portugués',
    'ja': 'Japonés',
    'ko': 'Coreano',
    'zh': 'Chino',
    'hi': 'Hindi',
    'ru': 'Ruso',
    'ar': 'Árabe',
    'sv': 'Sueco',
    'no': 'Noruego',
    'da': 'Danés',
    'fi': 'Finlandés',
    'nl': 'Neerlandés',
    'pl': 'Polaco',
    'tr': 'Turco',
    'ca': 'Catalán',
    'gl': 'Gallego',
    'eu': 'Euskera',
  };
}
