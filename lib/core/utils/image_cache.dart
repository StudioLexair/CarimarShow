import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Caché de imágenes de catálogo: disco (30 días) + precarga en memoria.
///
/// Dos motivos:
///   · En Android y escritorio, `cached_network_image` guarda en disco, pero
///     por defecto con una caducidad corta y pocos objetos: con 30 días y 500
///     objetos, volver a una pantalla ya visitada no re-descarga nada.
///   · En web no hay disco: lo que evita la recarga al cambiar de pestaña es
///     la caché en memoria de Flutter, y esa solo se llena si alguien pide las
///     imágenes antes de que hagan falta. De eso se encarga [precache].
abstract final class AppImages {
  static const String _cacheKey = 'carimarshow.imagenes';

  static final CacheManager cache = CacheManager(
    Config(
      _cacheKey,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 500,
    ),
  );

  static ImageProvider provider(String url) =>
      CachedNetworkImageProvider(url, cacheManager: cache);

  /// Olvida una URL concreta (la usa el botón «reintentar»).
  static Future<void> evict(String url) => cache.removeFile(url);

  /// Mete en la caché en memoria las [urls] que aún no estén.
  ///
  /// Falla en silencio: precargar es un optimismo, nunca un requisito. Se hace
  /// en paralelo pero con un tope, para no convertir la portada en un diluvio
  /// de peticiones al CDN de TMDB.
  static Future<void> precache(BuildContext context, Iterable<String?> urls) {
    final List<String> limpias = urls
        .whereType<String>()
        .take(40)
        .toList(growable: false);
    return Future.wait<void>(
      limpias.map(
        (String url) => precacheImage(
          provider(url),
          context,
        ).then((_) {}).catchError((Object _) {}),
      ),
    );
  }
}
