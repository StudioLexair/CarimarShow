import '../../domain/entities/media_item.dart';
import '../../domain/entities/media_type.dart';
import '../../domain/entities/watchlist_item.dart';
import 'json_utils.dart';

/// Serialización local de entidades.
///
/// Se usa para persistir «Mi lista» en el dispositivo (shared_preferences)
/// cuando no hay backend configurado. Es un formato propio y estable, separado
/// a propósito del de TMDB para no acoplar el almacenamiento local a los
/// cambios de la API externa.
abstract final class LocalCodec {
  LocalCodec._();

  static const int schemaVersion = 1;

  // ── MediaItem ────────────────────────────────────────────────────────

  static Map<String, dynamic> encodeMedia(MediaItem item) => <String, dynamic>{
    'id': item.id,
    'type': item.type.apiValue,
    'title': item.title,
    'originalTitle': item.originalTitle,
    'overview': item.overview,
    'posterPath': item.posterPath,
    'backdropPath': item.backdropPath,
    'voteAverage': item.voteAverage,
    'voteCount': item.voteCount,
    'releaseDate': item.releaseDate?.toIso8601String(),
    'genreIds': item.genreIds,
    'originalLanguage': item.originalLanguage,
    'popularity': item.popularity,
    'adult': item.adult,
  };

  static MediaItem? decodeMedia(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final int id = Json.intOr(raw, 'id', 0);
    if (id <= 0) return null;
    return MediaItem(
      id: id,
      type: MediaType.parse(Json.strOrNull(raw, 'type')),
      title: Json.str(raw, 'title'),
      originalTitle: Json.strOrNull(raw, 'originalTitle'),
      overview: Json.str(raw, 'overview'),
      posterPath: Json.strOrNull(raw, 'posterPath'),
      backdropPath: Json.strOrNull(raw, 'backdropPath'),
      voteAverage: Json.doubleOr(raw, 'voteAverage', 0),
      voteCount: Json.intOr(raw, 'voteCount', 0),
      releaseDate: Json.parseDate(Json.strOrNull(raw, 'releaseDate')),
      genreIds: Json.intList(raw, 'genreIds'),
      originalLanguage: Json.strOrNull(raw, 'originalLanguage'),
      popularity: Json.doubleOr(raw, 'popularity', 0),
      adult: Json.boolOr(raw, 'adult', false),
    );
  }

  // ── WatchlistItem ────────────────────────────────────────────────────

  static Map<String, dynamic> encodeWatchlistItem(WatchlistItem item) =>
      <String, dynamic>{
        'key': item.key,
        'media': encodeMedia(item.media),
        'status': item.status.name,
        'addedAt': item.addedAt.toIso8601String(),
        'updatedAt': item.updatedAt?.toIso8601String(),
        'progressPercent': item.progressPercent,
        'note': item.note,
      };

  static WatchlistItem? decodeWatchlistItem(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final MediaItem? media = decodeMedia(raw['media']);
    if (media == null) return null;

    final DateTime? added = Json.parseDate(Json.strOrNull(raw, 'addedAt'));

    return WatchlistItem(
      media: media,
      status: WatchlistStatus.parse(Json.strOrNull(raw, 'status')),
      addedAt: added ?? DateTime.now(),
      updatedAt: Json.parseDate(Json.strOrNull(raw, 'updatedAt')),
      progressPercent: Json.intOrNull(raw, 'progressPercent'),
      note: Json.strOrNull(raw, 'note'),
    );
  }

  static List<Map<String, dynamic>> encodeWatchlist(
    Iterable<WatchlistItem> items,
  ) => items.map(encodeWatchlistItem).toList(growable: false);

  /// Descodifica una lista guardada, descartando entradas corruptas o de un
  /// esquema incompatible. Nunca lanza: una lista local dañada no debe impedir
  /// arrancar la app.
  static List<WatchlistItem> decodeWatchlist(Object? raw) {
    if (raw is! List) return <WatchlistItem>[];
    final List<WatchlistItem> result = <WatchlistItem>[];
    for (final Object? entry in raw) {
      final WatchlistItem? decoded = decodeWatchlistItem(entry);
      if (decoded != null) result.add(decoded);
    }
    // Más recientes primero, que es como se muestra en la UI.
    result.sort(
      (WatchlistItem a, WatchlistItem b) => b.addedAt.compareTo(a.addedAt),
    );
    return result;
  }
}
