import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/media_item.dart';
import '../../domain/entities/watchlist_item.dart';
import '../../domain/repositories/watchlist_repository.dart';
import '../mappers/local_codec.dart';

/// «Mi lista» guardada en el dispositivo.
///
/// Se usa cuando no hay Supabase configurado. Cada usuario tiene su propia
/// clave, así una sesión de invitado y una cuenta local no se pisan entre sí.
///
/// La implementación mantiene la lista en memoria y la escribe en disco de
/// forma diferida: las operaciones son instantáneas y el stream notifica en el
/// mismo tick, que es lo que la UI necesita.
class LocalWatchlistRepository implements WatchlistRepository {
  LocalWatchlistRepository({SharedPreferences? preferences})
    : _prefs = preferences;

  static const String _keyPrefix = 'carimarshow.watchlist.';

  SharedPreferences? _prefs;

  final Map<String, List<WatchlistItem>> _byUser =
      <String, List<WatchlistItem>>{};

  final StreamController<String> _changes =
      StreamController<String>.broadcast();

  Future<void> initialize(SharedPreferences preferences) async {
    _prefs = preferences;
  }

  @override
  bool get isRemote => false;

  String _key(String userId) => '$_keyPrefix$userId';

  /// Lista en memoria, cargándola de disco la primera vez.
  List<WatchlistItem> _list(String userId) {
    return _byUser.putIfAbsent(userId, () {
      final String? raw = _prefs?.getString(_key(userId));
      if (raw == null || raw.isEmpty) return <WatchlistItem>[];
      try {
        return LocalCodec.decodeWatchlist(jsonDecode(raw));
      } catch (_) {
        // Lista dañada: se descarta para no bloquear la app.
        return <WatchlistItem>[];
      }
    });
  }

  @override
  Stream<List<WatchlistItem>> watch(String userId) async* {
    yield List<WatchlistItem>.unmodifiable(_list(userId));
    await for (final String changed in _changes.stream) {
      if (changed == userId) {
        yield List<WatchlistItem>.unmodifiable(_list(userId));
      }
    }
  }

  @override
  Future<List<WatchlistItem>> fetch(String userId) async =>
      List<WatchlistItem>.unmodifiable(_list(userId));

  @override
  Future<bool> contains(String userId, String mediaKey) async =>
      _list(userId).any((WatchlistItem i) => i.key == mediaKey);

  @override
  Future<bool> toggle(String userId, MediaItem media) async {
    final List<WatchlistItem> list = _list(userId);
    final int index = list.indexWhere(
      (WatchlistItem i) => i.key == media.uniqueKey,
    );
    if (index >= 0) {
      list.removeAt(index);
      await _flush(userId);
      return false;
    }
    list.insert(0, WatchlistItem.create(media));
    await _flush(userId);
    return true;
  }

  @override
  Future<void> add(String userId, MediaItem media) async {
    final List<WatchlistItem> list = _list(userId);
    if (list.any((WatchlistItem i) => i.key == media.uniqueKey)) return;
    list.insert(0, WatchlistItem.create(media));
    await _flush(userId);
  }

  @override
  Future<void> remove(String userId, String mediaKey) async {
    final List<WatchlistItem> list = _list(userId);
    final int before = list.length;
    list.removeWhere((WatchlistItem i) => i.key == mediaKey);
    if (list.length != before) await _flush(userId);
  }

  @override
  Future<void> updateStatus(
    String userId,
    String mediaKey,
    WatchlistStatus status,
  ) async {
    await _mutate(userId, mediaKey, (WatchlistItem item) {
      final int progress = switch (status) {
        WatchlistStatus.completed => 100,
        WatchlistStatus.watching => item.progressPercent ?? 0,
        WatchlistStatus.planned => 0,
      };
      return item.copyWith(
        status: status,
        progressPercent: progress,
        updatedAt: DateTime.now(),
      );
    });
  }

  @override
  Future<void> updateProgress(
    String userId,
    String mediaKey,
    int percent,
  ) async {
    final int clamped = percent.clamp(0, 100);
    await _mutate(userId, mediaKey, (WatchlistItem item) {
      final WatchlistStatus status = clamped >= 100
          ? WatchlistStatus.completed
          : (clamped > 0 ? WatchlistStatus.watching : item.status);
      return item.copyWith(
        status: status,
        progressPercent: clamped,
        updatedAt: DateTime.now(),
      );
    });
  }

  @override
  Future<void> clear(String userId) async {
    _byUser[userId] = <WatchlistItem>[];
    await _flush(userId);
  }

  // ══════════════════════════════════════════════════════════════════════

  Future<void> _mutate(
    String userId,
    String mediaKey,
    WatchlistItem Function(WatchlistItem item) transform,
  ) async {
    final List<WatchlistItem> list = _list(userId);
    final int index = list.indexWhere((WatchlistItem i) => i.key == mediaKey);
    if (index < 0) return;
    list[index] = transform(list[index]);
    await _flush(userId);
  }

  Future<void> _flush(String userId) async {
    final List<WatchlistItem> list = _list(userId);
    await _prefs?.setString(
      _key(userId),
      jsonEncode(LocalCodec.encodeWatchlist(list)),
    );
    if (!_changes.isClosed) _changes.add(userId);
  }

  @override
  void dispose() {
    _changes.close();
    _byUser.clear();
  }
}
