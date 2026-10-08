import '../entities/media_item.dart';
import '../entities/watchlist_item.dart';

/// Contrato de «Mi lista».
///
/// Devuelve un [Stream] porque la lista debe reaccionar en tiempo real: si el
/// usuario marca un título desde la ficha, la pestaña de Mi lista se actualiza
/// al instante sin refrescos manuales.
abstract interface class WatchlistRepository {
  /// Lista completa del usuario, ordenada por fecha de adición (más reciente primero).
  Stream<List<WatchlistItem>> watch(String userId);

  /// Consulta puntual, sin suscribirse.
  Future<List<WatchlistItem>> fetch(String userId);

  /// `true` si el título ya está guardado.
  Future<bool> contains(String userId, String mediaKey);

  /// Añade un título si no está; lo elimina si ya estaba.
  ///
  /// Devuelve el estado resultante: `true` = quedó guardado.
  Future<bool> toggle(String userId, MediaItem media);

  Future<void> add(String userId, MediaItem media);

  Future<void> remove(String userId, String mediaKey);

  /// Cambia el estado de seguimiento (pendiente / viendo / completado).
  Future<void> updateStatus(
    String userId,
    String mediaKey,
    WatchlistStatus status,
  );

  /// Marca el progreso de visionado (0–100) y pasa a «viendo» si procede.
  Future<void> updateProgress(String userId, String mediaKey, int percent);

  /// Vacía la lista por completo.
  Future<void> clear(String userId);

  /// `true` si los datos se sincronizan con un servidor.
  bool get isRemote;

  void dispose() {}
}
