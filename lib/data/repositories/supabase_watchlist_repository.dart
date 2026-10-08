import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../domain/entities/media_id.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/media_type.dart';
import '../../domain/entities/watchlist_item.dart';
import '../../domain/repositories/watchlist_repository.dart';
import '../mappers/json_utils.dart';

/// «Mi lista» sincronizada con Supabase.
///
/// Usa Realtime para que la lista se actualice entre dispositivos sin recargar:
/// si añades un título en el móvil, aparece en la tablet al instante.
///
/// Requiere aplicar `supabase/migrations/0001_initial_schema.sql`, que crea la
/// tabla `watchlist` con RLS (cada usuario solo ve sus filas).
class SupabaseWatchlistRepository implements WatchlistRepository {
  SupabaseWatchlistRepository({required this.client});

  static const String _table = 'watchlist';

  final sb.SupabaseClient client;

  @override
  bool get isRemote => true;

  @override
  Stream<List<WatchlistItem>> watch(String userId) {
    return client
        .from(_table)
        .stream(primaryKey: <String>['user_id', 'media_type', 'tmdb_id'])
        .eq('user_id', userId)
        .order('added_at', ascending: false)
        .map(_decodeRows);
  }

  @override
  Future<List<WatchlistItem>> fetch(String userId) async {
    final List<Map<String, dynamic>> rows = await client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('added_at', ascending: false);
    return _decodeRows(rows);
  }

  @override
  Future<bool> contains(String userId, String mediaKey) async {
    final MediaId? ref = MediaId.tryParse(mediaKey);
    if (ref == null) return false;
    // `maybeSingle` devuelve la fila o null. Es más portable y barato que un
    // `head + count`, y evita depender de la API de conteo de PostgREST.
    final Map<String, dynamic>? row = await client
        .from(_table)
        .select('tmdb_id')
        .eq('user_id', userId)
        .eq('media_type', ref.type.apiValue)
        .eq('tmdb_id', ref.id)
        .maybeSingle();
    return row != null;
  }

  @override
  Future<bool> toggle(String userId, MediaItem media) async {
    final bool exists = await contains(userId, media.uniqueKey);
    if (exists) {
      await remove(userId, media.uniqueKey);
      return false;
    }
    await add(userId, media);
    return true;
  }

  /// Inserta (o refresca) un título en la lista del usuario.
  ///
  /// **No se envían `overview` ni `original_language`**: la migración
  /// `0002_scale_optimizations.sql` los eliminó de la tabla. La sinopsis era el
  /// campo más caro de la fila (~250 bytes) y nunca se pinta en la lista —solo
  /// en la ficha, que ya la pide a TMDB con `append_to_response`. Guardarla aquí
  /// era coste puro: quitándola caben ~2,3× más usuarios en los 500 MB del plan
  /// gratuito de Supabase.
  ///
  /// Lo que sí se guarda es justo lo necesario para pintar la lista **sin una
  /// sola llamada a red**: título, póster, fondo, nota, votos, fecha y géneros.
  ///
  /// [_decodeRow] sigue leyendo esas dos columnas de forma tolerante, así que
  /// este repositorio funciona igual contra un esquema con 0001 solamente.
  @override
  Future<void> add(String userId, MediaItem media) async {
    final DateTime now = DateTime.now().toUtc();
    await client.from(_table).upsert(<String, dynamic>{
      'user_id': userId,
      'media_type': media.type.apiValue,
      'tmdb_id': media.id,
      'title': _clip(media.displayTitle, 400),
      'poster_path': _clip(media.posterPath, 120),
      'backdrop_path': _clip(media.backdropPath, 120),
      'vote_average': media.voteAverage,
      'vote_count': media.voteCount,
      'release_date': media.releaseDate?.toIso8601String(),
      'genre_ids': media.genreIds,
      'status': WatchlistStatus.planned.name,
      'progress_percent': 0,
      'added_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
  }

  /// Recorta al límite declarado en la base de datos.
  ///
  /// Las columnas pasaron de `text` a `varchar(n)` en 0002 para que un cliente
  /// malicioso no pueda hinchar la tabla. TMDB nunca supera estos tamaños, así
  /// que en la práctica es un seguro que no corta nada.
  static String? _clip(String? value, int max) {
    if (value == null) return null;
    return value.length <= max ? value : value.substring(0, max);
  }

  @override
  Future<void> remove(String userId, String mediaKey) async {
    final MediaId? ref = MediaId.tryParse(mediaKey);
    if (ref == null) return;
    await client
        .from(_table)
        .delete()
        .eq('user_id', userId)
        .eq('media_type', ref.type.apiValue)
        .eq('tmdb_id', ref.id);
  }

  @override
  Future<void> updateStatus(
    String userId,
    String mediaKey,
    WatchlistStatus status,
  ) async {
    final MediaId? ref = MediaId.tryParse(mediaKey);
    if (ref == null) return;
    final int progress = switch (status) {
      WatchlistStatus.completed => 100,
      WatchlistStatus.watching => 0,
      WatchlistStatus.planned => 0,
    };
    await client
        .from(_table)
        .update(<String, dynamic>{
          'status': status.name,
          'progress_percent': progress,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('media_type', ref.type.apiValue)
        .eq('tmdb_id', ref.id);
  }

  @override
  Future<void> updateProgress(
    String userId,
    String mediaKey,
    int percent,
  ) async {
    final MediaId? ref = MediaId.tryParse(mediaKey);
    if (ref == null) return;
    final int clamped = percent.clamp(0, 100);
    final String status = clamped >= 100
        ? WatchlistStatus.completed.name
        : (clamped > 0
              ? WatchlistStatus.watching.name
              : WatchlistStatus.planned.name);
    await client
        .from(_table)
        .update(<String, dynamic>{
          'status': status,
          'progress_percent': clamped,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('media_type', ref.type.apiValue)
        .eq('tmdb_id', ref.id);
  }

  @override
  Future<void> clear(String userId) async {
    await client.from(_table).delete().eq('user_id', userId);
  }

  // ══════════════════════════════════════════════════════════════════════

  /// Reconstruye [MediaItem] a partir de las columnas denormalizadas.
  ///
  /// Se guardan título, póster y sinopsis en la propia fila para poder pintar la
  /// lista sin volver a consultar TMDB: funciona offline y es mucho más rápido.
  static List<WatchlistItem> _decodeRows(List<Map<String, dynamic>> rows) {
    final List<WatchlistItem> items = <WatchlistItem>[];
    for (final Map<String, dynamic> row in rows) {
      final WatchlistItem? decoded = _decodeRow(row);
      if (decoded != null) items.add(decoded);
    }
    return items;
  }

  static WatchlistItem? _decodeRow(Map<String, dynamic> row) {
    final int tmdbId = Json.intOr(row, 'tmdb_id', 0);
    if (tmdbId <= 0) return null;

    final MediaType type = MediaType.parse(Json.strOrNull(row, 'media_type'));

    final MediaItem media = MediaItem(
      id: tmdbId,
      type: type,
      title: Json.str(row, 'title'),
      overview: Json.str(row, 'overview'),
      posterPath: Json.strOrNull(row, 'poster_path'),
      backdropPath: Json.strOrNull(row, 'backdrop_path'),
      voteAverage: Json.doubleOr(row, 'vote_average', 0),
      voteCount: Json.intOr(row, 'vote_count', 0),
      releaseDate: Json.parseDate(Json.strOrNull(row, 'release_date')),
      genreIds: Json.intList(row, 'genre_ids'),
      originalLanguage: Json.strOrNull(row, 'original_language'),
    );

    final DateTime? added = Json.parseDate(Json.strOrNull(row, 'added_at'));

    return WatchlistItem(
      media: media,
      status: WatchlistStatus.parse(Json.strOrNull(row, 'status')),
      addedAt: added ?? DateTime.now(),
      updatedAt: Json.parseDate(Json.strOrNull(row, 'updated_at')),
      progressPercent: Json.intOrNull(row, 'progress_percent'),
      note: Json.strOrNull(row, 'note'),
    );
  }

  @override
  void dispose() {}
}
