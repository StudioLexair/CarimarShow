import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/media_id.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/media_type.dart';
import '../../domain/entities/watchlist_item.dart';
import '../../domain/repositories/watchlist_repository.dart';
import 'auth_providers.dart';
import 'core_providers.dart';

// ══════════════════════════════════════════════════════════════════════════
//  Lectura
// ══════════════════════════════════════════════════════════════════════════

/// Lista completa del usuario actual.
///
/// Es un `StreamProvider`: cuando el backend es Supabase, los cambios hechos
/// desde otro dispositivo llegan solos gracias a Realtime.
final StreamProvider<List<WatchlistItem>> watchlistProvider =
    StreamProvider<List<WatchlistItem>>((Ref ref) {
      final WatchlistRepository repository = ref.watch(
        watchlistRepositoryProvider,
      );
      final String userId = ref.watch(currentUserIdProvider);
      return repository.watch(userId);
    });

/// Claves (`"movie:155"`) presentes en la lista.
///
/// Se deriva de [watchlistProvider] para que los botones «+ / ✓» de cada póster
/// sepan su estado sin recorrer la lista entera: es una búsqueda O(1).
final Provider<Set<String>> watchlistKeysProvider = Provider<Set<String>>((
  Ref ref,
) {
  final List<WatchlistItem>? items = ref.watch(watchlistProvider).value;
  if (items == null) return const <String>{};
  return items.map((WatchlistItem i) => i.key).toSet();
});

/// ¿Está este título guardado?
final isInWatchlistProvider = Provider.family<bool, MediaId>((
  Ref ref,
  MediaId id,
) {
  final Set<String> keys = ref.watch(watchlistKeysProvider);
  return keys.contains(id.key);
});

/// Entrada concreta de la lista, o `null` si no está guardada.
final watchlistEntryProvider = Provider.family<WatchlistItem?, MediaId>((
  Ref ref,
  MediaId id,
) {
  final List<WatchlistItem>? items = ref.watch(watchlistProvider).value;
  if (items == null) return null;
  for (final WatchlistItem item in items) {
    if (item.key == id.key) return item;
  }
  return null;
});

/// Filtro activo de la pantalla «Mi lista».
class WatchlistFilterNotifier extends Notifier<WatchlistStatus?> {
  @override
  WatchlistStatus? build() => null;

  void set(WatchlistStatus? status) => state = status;

  void toggle(WatchlistStatus status) =>
      state = state == status ? null : status;
}

final NotifierProvider<WatchlistFilterNotifier, WatchlistStatus?>
watchlistFilterProvider =
    NotifierProvider<WatchlistFilterNotifier, WatchlistStatus?>(
      WatchlistFilterNotifier.new,
    );

/// Lista ya filtrada y ordenada según el filtro activo.
final Provider<List<WatchlistItem>> visibleWatchlistProvider =
    Provider<List<WatchlistItem>>((Ref ref) {
      final List<WatchlistItem> all =
          ref.watch(watchlistProvider).value ?? const <WatchlistItem>[];
      final WatchlistStatus? filter = ref.watch(watchlistFilterProvider);
      if (filter == null) return all;
      return all
          .where((WatchlistItem i) => i.status == filter)
          .toList(growable: false);
    });

/// Recuento por estado, para las pestañas de «Mi lista».
class WatchlistStats extends Equatable {
  const WatchlistStats({
    this.total = 0,
    this.planned = 0,
    this.watching = 0,
    this.completed = 0,
    this.movies = 0,
    this.series = 0,
  });

  final int total;
  final int planned;
  final int watching;
  final int completed;
  final int movies;
  final int series;

  int countFor(WatchlistStatus? status) => switch (status) {
    WatchlistStatus.planned => planned,
    WatchlistStatus.watching => watching,
    WatchlistStatus.completed => completed,
    null => total,
  };

  bool get isEmpty => total == 0;

  @override
  List<Object?> get props => <Object?>[
    total,
    planned,
    watching,
    completed,
    movies,
    series,
  ];
}

final Provider<WatchlistStats> watchlistStatsProvider =
    Provider<WatchlistStats>((Ref ref) {
      final List<WatchlistItem> all =
          ref.watch(watchlistProvider).value ?? const <WatchlistItem>[];

      int count(WatchlistStatus status) =>
          all.where((WatchlistItem i) => i.status == status).length;

      return WatchlistStats(
        total: all.length,
        planned: count(WatchlistStatus.planned),
        watching: count(WatchlistStatus.watching),
        completed: count(WatchlistStatus.completed),
        movies: all.where((WatchlistItem i) => i.type.isMovie).length,
        series: all.where((WatchlistItem i) => i.type.isTv).length,
      );
    });

/// Títulos marcados como «viendo», con progreso: alimenta «Continuar viendo».
final Provider<List<WatchlistItem>> continueWatchingProvider =
    Provider<List<WatchlistItem>>((Ref ref) {
      final List<WatchlistItem> all =
          ref.watch(watchlistProvider).value ?? const <WatchlistItem>[];
      return all
          .where(
            (WatchlistItem i) =>
                i.status == WatchlistStatus.watching &&
                (i.progressPercent ?? 0) > 0 &&
                (i.progressPercent ?? 0) < 100,
          )
          .toList(growable: false);
    });

/// `true` si la lista se sincroniza con un servidor.
///
/// La UI lo muestra en Ajustes para que el usuario sepa si sus datos están solo
/// en este dispositivo.
final Provider<bool> watchlistIsSyncedProvider = Provider<bool>(
  (Ref ref) => ref.watch(watchlistRepositoryProvider).isRemote,
);

// ══════════════════════════════════════════════════════════════════════════
//  Escritura
// ══════════════════════════════════════════════════════════════════════════

/// Estado de la UI durante las operaciones de escritura.
class WatchlistUiState extends Equatable {
  const WatchlistUiState({
    this.pendingKeys = const <String>{},
    this.lastError,
    this.lastNotice,
  });

  /// Claves con una operación en curso, para deshabilitar su botón.
  final Set<String> pendingKeys;

  final String? lastError;

  /// Mensaje de confirmación («Añadido a Mi lista») para el SnackBar.
  final String? lastNotice;

  bool isPending(String key) => pendingKeys.contains(key);

  WatchlistUiState copyWith({
    Set<String>? pendingKeys,
    String? lastError,
    String? lastNotice,
    bool clearMessages = false,
  }) => WatchlistUiState(
    pendingKeys: pendingKeys ?? this.pendingKeys,
    lastError: clearMessages ? null : (lastError ?? this.lastError),
    lastNotice: clearMessages ? null : (lastNotice ?? this.lastNotice),
  );

  @override
  List<Object?> get props => <Object?>[pendingKeys, lastError, lastNotice];
}

class WatchlistController extends Notifier<WatchlistUiState> {
  @override
  WatchlistUiState build() => const WatchlistUiState();

  WatchlistRepository get _repo => ref.read(watchlistRepositoryProvider);

  String get _userId => ref.read(currentUserIdProvider);

  /// Añade o quita un título. Devuelve `true` si quedó guardado.
  Future<bool> toggle(MediaItem media) => _run(
    media.uniqueKey,
    () => _repo.toggle(_userId, media),
    successNotice: (bool saved) => saved
        ? '«${media.displayTitle}» añadido a Mi lista'
        : '«${media.displayTitle}» quitado de Mi lista',
  );

  Future<void> add(MediaItem media) => _run(media.uniqueKey, () async {
    await _repo.add(_userId, media);
    return true;
  }, successNotice: (_) => '«${media.displayTitle}» añadido a Mi lista');

  Future<void> remove(String mediaKey, {String? title}) => _run(
    mediaKey,
    () async {
      await _repo.remove(_userId, mediaKey);
      return false;
    },
    successNotice: (_) =>
        title == null ? 'Quitado de Mi lista' : '«$title» quitado de Mi lista',
  );

  Future<void> setStatus(String mediaKey, WatchlistStatus status) =>
      _run(mediaKey, () async {
        await _repo.updateStatus(_userId, mediaKey, status);
        return true;
      }, successNotice: (_) => 'Estado: ${status.label}');

  Future<void> setProgress(String mediaKey, int percent) =>
      _run(mediaKey, () async {
        await _repo.updateProgress(_userId, mediaKey, percent.clamp(0, 100));
        return true;
      });

  Future<void> clearAll() async {
    state = state.copyWith(clearMessages: true);
    try {
      await _repo.clear(_userId);
      if (!ref.mounted) return;
      state = state.copyWith(lastNotice: 'Lista vaciada');
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(lastError: _describe(error));
    }
  }

  /// Borra el último mensaje para que no se repita el SnackBar al reconstruir.
  void consumeMessages() {
    if (state.lastError != null || state.lastNotice != null) {
      state = state.copyWith(clearMessages: true);
    }
  }

  /// Ejecuta una operación marcando la clave como «en curso».
  Future<bool> _run(
    String key,
    Future<bool> Function() operation, {
    String Function(bool result)? successNotice,
  }) async {
    state = state.copyWith(
      pendingKeys: <String>{...state.pendingKeys, key},
      clearMessages: true,
    );
    try {
      final bool result = await operation();
      if (!ref.mounted) return result;
      state = state.copyWith(
        pendingKeys: _without(state.pendingKeys, key),
        lastNotice: successNotice?.call(result),
      );
      return result;
    } catch (error) {
      if (!ref.mounted) return false;
      state = state.copyWith(
        pendingKeys: _without(state.pendingKeys, key),
        lastError: _describe(error),
      );
      return false;
    }
  }

  static Set<String> _without(Set<String> keys, String key) =>
      keys.where((String k) => k != key).toSet();

  /// Mensaje legible a partir de errores de Supabase o de red.
  static String _describe(Object error) {
    final String text = error.toString();
    if (text.contains('row-level security') || text.contains('42501')) {
      return 'Permisos insuficientes. Revisa las políticas RLS de la tabla '
          '`watchlist`.';
    }
    if (text.contains('relation') && text.contains('does not exist')) {
      return 'Falta la tabla `watchlist`. Aplica la migración de '
          '`supabase/migrations/0001_initial_schema.sql`.';
    }
    if (text.contains('Failed to fetch') || text.contains('SocketException')) {
      return 'Sin conexión. El cambio no se pudo guardar.';
    }
    return 'No se pudo actualizar Mi lista.';
  }
}

final NotifierProvider<WatchlistController, WatchlistUiState>
watchlistControllerProvider =
    NotifierProvider<WatchlistController, WatchlistUiState>(
      WatchlistController.new,
    );

/// Utilidad para construir un [MediaId] desde un elemento de catálogo.
MediaId mediaIdOf(MediaItem item) => MediaId(item.type, item.id);

/// Lista filtrada por tipo, para las pestañas de «Mi lista».
final watchlistByTypeProvider =
    Provider.family<List<WatchlistItem>, MediaType?>((
      Ref ref,
      MediaType? type,
    ) {
      final List<WatchlistItem> all = ref.watch(visibleWatchlistProvider);
      if (type == null) return all;
      return all
          .where((WatchlistItem i) => i.type == type)
          .toList(growable: false);
    });
