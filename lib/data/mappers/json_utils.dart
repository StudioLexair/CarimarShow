import '../../core/errors/app_exception.dart';

/// Lectores tolerantes de JSON.
///
/// TMDB es inconsistente: omite campos, usa `null` donde otras APIs usarían
/// cadena vacía, y mezcla `title`/`name` según el tipo de recurso. Cada acceso
/// pasa por aquí para que un dato raro degrade a un valor por defecto en vez de
/// reventar el parseo de una lista entera.
abstract final class Json {
  Json._();

  /// `String` o `null`, tratando `''` como ausente.
  static String? strOrNull(Map<String, dynamic> json, String key) {
    final Object? raw = json[key];
    if (raw is String) {
      final String trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (raw == null) return null;
    return raw.toString();
  }

  /// `String` con valor por defecto. Nunca devuelve `null`.
  static String str(
    Map<String, dynamic> json,
    String key, {
    String fallback = '',
  }) => strOrNull(json, key) ?? fallback;

  /// `int` aceptando num y cadenas numéricas.
  static int intOr(Map<String, dynamic> json, String key, int fallback) {
    final Object? raw = json[key];
    return switch (raw) {
      final int i => i,
      final num n => n.toInt(),
      final String s => int.tryParse(s) ?? fallback,
      _ => fallback,
    };
  }

  static int? intOrNull(Map<String, dynamic> json, String key) {
    final Object? raw = json[key];
    return switch (raw) {
      final int i => i,
      final num n => n.toInt(),
      final String s => int.tryParse(s),
      _ => null,
    };
  }

  /// `double` aceptando int, num y cadenas.
  static double doubleOr(
    Map<String, dynamic> json,
    String key,
    double fallback,
  ) {
    final Object? raw = json[key];
    return switch (raw) {
      final double d => d,
      final num n => n.toDouble(),
      final String s => double.tryParse(s) ?? fallback,
      _ => fallback,
    };
  }

  static double? doubleOrNull(Map<String, dynamic> json, String key) {
    final Object? raw = json[key];
    return switch (raw) {
      final double d => d,
      final num n => n.toDouble(),
      final String s => double.tryParse(s),
      _ => null,
    };
  }

  static bool boolOr(Map<String, dynamic> json, String key, bool fallback) {
    final Object? raw = json[key];
    return switch (raw) {
      final bool b => b,
      final num n => n != 0,
      final String s => s.toLowerCase() == 'true' || s == '1',
      _ => fallback,
    };
  }

  /// Fecha ISO-8601 → [DateTime], o `null`.
  ///
  /// TMDB devuelve fechas parciales (`2008-07-16`) y marcas de tiempo completas
  /// (`2008-07-16T12:00:00.000Z`); ambas se aceptan.
  static DateTime? dateOrNull(Map<String, dynamic> json, String key) {
    final String? raw = strOrNull(json, key);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  static DateTime? parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  /// Subobjeto JSON, o mapa vacío si falta o no es un objeto.
  static Map<String, dynamic> objOrEmpty(
    Map<String, dynamic> json,
    String key,
  ) {
    final Object? raw = json[key];
    return raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
  }

  static Map<String, dynamic>? objOrNull(
    Map<String, dynamic> json,
    String key,
  ) {
    final Object? raw = json[key];
    return raw is Map<String, dynamic> ? raw : null;
  }

  /// Lista de objetos JSON, filtrando entradas que no lo sean.
  static List<Map<String, dynamic>> list(
    Map<String, dynamic> json,
    String key,
  ) {
    final Object? raw = json[key];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  /// Lista de cadenas, filtrando nulos y vacíos.
  static List<String> strList(Map<String, dynamic> json, String key) {
    final Object? raw = json[key];
    if (raw is! List) return const <String>[];
    return raw
        .whereType<Object>()
        .map((Object e) => e.toString().trim())
        .where((String s) => s.isNotEmpty)
        .toList(growable: false);
  }

  /// Lista de enteros (p. ej. `genre_ids`).
  static List<int> intList(Map<String, dynamic> json, String key) {
    final Object? raw = json[key];
    if (raw is! List) return const <int>[];
    return raw
        .map(
          (Object? e) => switch (e) {
            final int i => i,
            final num n => n.toInt(),
            final String s => int.tryParse(s),
            _ => null,
          },
        )
        .whereType<int>()
        .toList(growable: false);
  }

  /// Extrae un campo anidado: `list(json, 'a')['b']` de forma segura.
  static String? nestedStr(Map<String, dynamic> json, List<String> path) {
    Map<String, dynamic> current = json;
    for (int i = 0; i < path.length - 1; i++) {
      final Object? next = current[path[i]];
      if (next is! Map<String, dynamic>) return null;
      current = next;
    }
    return strOrNull(current, path.last);
  }

  /// Convierte una lista de mapas aplicando [mapper].
  ///
  /// Si un elemento falla, el error se envuelve en [ParsingException] con
  /// contexto para poder diagnosticarlo. Para listas donde es preferible
  /// conservar los elementos válidos, usa [mapListLenient].
  static List<T> mapList<T>(
    List<Map<String, dynamic>> items,
    T Function(Map<String, dynamic> json) mapper, {
    String context = '',
  }) {
    final List<T> result = <T>[];
    for (final Map<String, dynamic> item in items) {
      try {
        result.add(mapper(item));
      } catch (error, stackTrace) {
        // Solo diagnóstico; nunca se propaga.
        throw ParsingException(
          detail:
              'Fallo al mapear un elemento${context.isEmpty ? '' : ' de $context'}: $error',
          cause: error,
          stackTrace: stackTrace,
        );
      }
    }
    return result;
  }

  /// Versión indulgente de [mapList]: salta los elementos problemáticos.
  static List<T> mapListLenient<T>(
    List<Map<String, dynamic>> items,
    T? Function(Map<String, dynamic> json) mapper,
  ) {
    final List<T> result = <T>[];
    for (final Map<String, dynamic> item in items) {
      try {
        final T? mapped = mapper(item);
        if (mapped != null) result.add(mapped);
      } catch (_) {
        // Elemento inválido: se descarta en silencio.
      }
    }
    return result;
  }
}
