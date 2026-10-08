import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Caché en disco de las respuestas del catálogo.
///
/// Implementa la regla que pidió el cliente: *«¿hay internet? busca y cachea;
/// ¿no hay? busca local»*. Cada respuesta de TMDB que la app consulta se
/// guarda aquí; cuando la red falla (sin conexión, DNS caído, 429, 5xx) se
/// sirve la última copia buena en vez de un error.
///
/// Por qué `SharedPreferences` y no ficheros:
///   · Ya es dependencia del proyecto y funciona en las seis plataformas,
///     incluida web (localStorage), sin canales de plataforma nuevos.
///   · La caché es un puñado de JSON de unos KB; no necesita un sistema de
///     ficheros.
///
/// Límite duro de tamaño ([maxBytes], 2 MB por defecto): en web el
/// localStorage ronda los 5 MB y pasarse deja la sesión sin sitio. Al
/// escribir se evolucionan las entradas más antiguas hasta volver al límite
/// (LRU), así que la caché nunca crece sin control y por eso existe el botón
/// «liberar espacio» en Configuración.
class CatalogCache {
  CatalogCache(this._prefs, {this.maxBytes = 2 * 1024 * 1024});

  static const String _indexKey = 'carimarshow.cache.index';
  static const String _entryPrefix = 'carimarshow.cache.e.';

  final SharedPreferences _prefs;
  final int maxBytes;

  /// Guarda [payload] (JSON ya serializado) bajo [key].
  ///
  /// Nunca lanza: una caché que falla no debe tumbar la petición que iba
  /// bien. Si escribir falla, simplemente no se cachea.
  Future<void> write(String key, String payload) async {
    try {
      final int bytes = utf8.encode(payload).length;
      if (bytes > maxBytes) return; // una sola respuesta no cabe: se descarta
      await _prefs.setString(_entryPrefix + key, payload);
      final Map<String, _Entry> index = _readIndex();
      index[key] = _Entry(
        bytes: bytes,
        at: DateTime.now().millisecondsSinceEpoch,
      );
      await _evict(index);
      await _writeIndex(index);
    } catch (_) {
      // Caché degrada en silencio: ver la doc de la clase.
    }
  }

  /// Última copia buena de [key], o `null` si no está.
  ///
  /// Toca la marca de tiempo (LRU): lo que se sigue consultando no se
  /// evoluciona.
  Future<String?> read(String key) async {
    try {
      final String? value = _prefs.getString(_entryPrefix + key);
      if (value == null) return null;
      final Map<String, _Entry> index = _readIndex();
      final _Entry? e = index[key];
      index[key] = _Entry(
        bytes: e?.bytes ?? utf8.encode(value).length,
        at: DateTime.now().millisecondsSinceEpoch,
      );
      await _writeIndex(index);
      return value;
    } catch (_) {
      return null;
    }
  }

  /// Bytes ocupados ahora mismo, para mostrarlos en Configuración.
  int sizeBytes() =>
      _readIndex().values.fold<int>(0, (int a, _Entry e) => a + e.bytes);

  /// Número de respuestas guardadas.
  int entryCount() => _readIndex().length;

  /// Vacía la caché y devuelve cuántos bytes liberó. Es lo que hace el botón
  /// «liberar espacio» de Configuración.
  Future<int> clear() async {
    final Map<String, _Entry> index = _readIndex();
    final int freed = index.values.fold<int>(
      0,
      (int a, _Entry e) => a + e.bytes,
    );
    for (final String key in index.keys) {
      await _prefs.remove(_entryPrefix + key);
    }
    await _prefs.remove(_indexKey);
    return freed;
  }

  // ══════════════════════════════════════════════════════════════════════

  Map<String, _Entry> _readIndex() {
    final String? raw = _prefs.getString(_indexKey);
    if (raw == null || raw.isEmpty) return <String, _Entry>{};
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return <String, _Entry>{};
      return decoded.map<String, _Entry>(
        (String k, dynamic v) =>
            MapEntry<String, _Entry>(k, _Entry.fromJson(v)),
      );
    } catch (_) {
      return <String, _Entry>{};
    }
  }

  Future<void> _writeIndex(Map<String, _Entry> index) => _prefs.setString(
    _indexKey,
    jsonEncode(
      index.map<String, dynamic>(
        (String k, _Entry e) => MapEntry<String, dynamic>(k, e.toJson()),
      ),
    ),
  );

  /// Evoluciona las entradas más antiguas hasta quedar por debajo del límite.
  Future<void> _evict(Map<String, _Entry> index) async {
    int total = index.values.fold<int>(0, (int a, _Entry e) => a + e.bytes);
    if (total <= maxBytes) return;
    final List<String> porAntiguedad = index.keys.toList()
      ..sort((String a, String b) => index[a]!.at.compareTo(index[b]!.at));
    for (final String key in porAntiguedad) {
      if (total <= maxBytes) break;
      total -= index.remove(key)!.bytes;
      await _prefs.remove(_entryPrefix + key);
    }
  }
}

class _Entry {
  const _Entry({required this.bytes, required this.at});

  factory _Entry.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return _Entry(
        bytes: (json['b'] as num?)?.toInt() ?? 0,
        at: (json['t'] as num?)?.toInt() ?? 0,
      );
    }
    return const _Entry(bytes: 0, at: 0);
  }

  final int bytes;
  final int at;

  Map<String, dynamic> toJson() => <String, dynamic>{'b': bytes, 't': at};
}
