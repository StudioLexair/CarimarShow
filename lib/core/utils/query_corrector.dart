import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Normaliza texto para comparar: minúsculas, sin acentos, sin signos.
const Map<String, String> _sinAccent = <String, String>{
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'ã': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'õ': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ñ': 'n',
  'ç': 'c',
  'ý': 'y',
  'ÿ': 'y',
};

String normalizeQuery(String raw) {
  final StringBuffer out = StringBuffer();
  for (final String ch in raw.toLowerCase().split('')) {
    out.write(_sinAccent[ch] ?? ch);
  }
  return out
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Distancia de Levenshtein con cota temprana: suficiente para erratas
/// («resindente» → «residente»), barata para miles de entradas.
int _levenshtein(String a, String b, int max) {
  if (a == b) return 0;
  if ((a.length - b.length).abs() > max) return max + 1;
  var prev = List<int>.generate(b.length + 1, (int i) => i);
  var curr = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    curr[0] = i;
    var best = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      curr[j] = <int>[
        prev[j] + 1,
        curr[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((int x, int y) => x < y ? x : y);
      if (curr[j] < best) best = curr[j];
    }
    if (best > max) return max + 1;
    final t = prev;
    prev = curr;
    curr = t;
  }
  return prev[b.length];
}

/// Léxico de títulos conocidos, persistido en el dispositivo.
///
/// Se alimenta solo con todo catálogo que pasa por la app (tendencias,
/// búsquedas, sugerencias): cuanto más se usa, mejor corrige. Funciona sin
/// conexión porque vive en `SharedPreferences`.
class LexiconStore {
  LexiconStore._();

  static final LexiconStore instance = LexiconStore._();
  static const String _key = 'carimarshow.lexicon';
  static const int _max = 1200;

  SharedPreferences? _prefs;
  final Map<String, String> _entries = <String, String>{};
  Timer? _guardado;

  void bind(SharedPreferences prefs) {
    if (_prefs != null) return;
    _prefs = prefs;
    try {
      final String? raw = prefs.getString(_key);
      if (raw != null) {
        for (final dynamic t in jsonDecode(raw) as List<dynamic>) {
          final String original = t as String;
          _entries[normalizeQuery(original)] = original;
        }
      }
    } catch (_) {
      _entries.clear();
    }
  }

  int get size => _entries.length;

  void addMany(Iterable<String> titles) {
    var changed = false;
    for (final String t in titles) {
      if (t.trim().isEmpty) continue;
      final String n = normalizeQuery(t);
      if (n.length < 3 || _entries.containsKey(n)) continue;
      _entries[n] = t;
      changed = true;
    }
    if (!changed) return;
    // Poda: se queda con las entradas más recientes.
    if (_entries.length > _max) {
      // Map conserva el orden de inserción: caen las más antiguas.
      final List<String> sobrantes = _entries.keys
          .take(_entries.length - _max)
          .toList();
      for (final String k in sobrantes) {
        _entries.remove(k);
      }
    }
    _guardado?.cancel();
    _guardado = Timer(const Duration(seconds: 3), _persist);
  }

  void _persist() {
    try {
      _prefs?.setString(_key, jsonEncode(_entries.values.toList()));
    } catch (_) {
      // Sin persistencia el corrector sigue funcionando en memoria.
    }
  }
}

/// Corrector de consultas: «resindente evil» → «Resident Evil».
///
/// No es magia ni una API externa: compara la consulta normalizada contra el
/// léxico local con distancia de Levenshtein acotada al largo de la palabra.
/// Con léxico vacío (primera instalación y sin conexión) no sugiere nada y la
/// búsqueda se comporta exactamente como antes.
abstract final class QueryCorrector {
  static String? suggest(String query) {
    final String q = normalizeQuery(query);
    if (q.length < 4) return null;
    final Map<String, String> entries = LexiconStore.instance._entries;
    if (entries.containsKey(q))
      return null; // existe tal cual: nada que corregir

    final int max = q.length <= 6 ? 1 : (q.length <= 11 ? 2 : 3);
    String? best;
    var bestD = max + 1;
    for (final MapEntry<String, String> e in entries.entries) {
      final int d = _levenshtein(q, e.key, bestD - 1);
      if (d < bestD) {
        bestD = d;
        best = e.value;
        if (d == 1) break;
      }
    }
    return bestD <= max ? best : null;
  }
}
