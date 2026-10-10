import 'package:dio/dio.dart';

import '../constants/tmdb_constants.dart';

/// Calidad de la conexión medida de verdad, no supuesta.
enum NetTier {
  /// Sin conexión: se sirve caché sin ni siquiera intentar la red.
  offline,

  /// Conexión lenta o cara: se piden imágenes pequeñas y se cachea agresivo.
  slow,

  /// Conexión buena: calidad normal.
  good,
}

/// Sonda de red: responde «¿hay internet ahora mismo?» y «¿cómo de bueno es».
///
/// El cliente pidió que la app *verifique* la conexión antes de decidir entre
/// red y caché, en vez de descubrir a base de fallos que no hay red (que es
/// lo que producía los pósters negados y los «toca para reintentar» en
/// conexiones 3G malas). El resultado se cachea 20 segundos: comprobar la red
/// en cada petición sería más caro que el ahorro.
abstract final class NetworkProbe {
  static const Duration _valido = Duration(seconds: 20);

  static DateTime? _marcado;
  static NetTier _tier = NetTier.good;
  static int _rttMs = 0;

  /// Última latencia medida, para el medidor de Ajustes.
  static int get rttMs => _rttMs;

  /// El tier sin esperar: si aún no se midió, asume `good`.
  static NetTier get cachedTier => _tier;

  static Future<NetTier> tier({bool force = false}) async {
    final DateTime? m = _marcado;
    if (!force && m != null && DateTime.now().difference(m) < _valido) {
      return _tier;
    }
    final Stopwatch sw = Stopwatch()..start();
    final Dio dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(milliseconds: 2500),
        receiveTimeout: const Duration(milliseconds: 2500),
      ),
    );
    try {
      // Un HEAD a la API sin credenciales devuelve 401, pero eso significa que
      // la red funciona: aquí solo interesa que haya respuesta del servidor.
      await dio.head<dynamic>(Tmdb.baseUrl);
      _rttMs = sw.elapsedMilliseconds;
      _tier = _rttMs > 900 ? NetTier.slow : NetTier.good;
    } on DioException catch (e) {
      if (e.response != null) {
        // Llegó una respuesta HTTP: hay red, aunque sea lenta.
        _rttMs = sw.elapsedMilliseconds;
        _tier = _rttMs > 900 ? NetTier.slow : NetTier.good;
      } else {
        _rttMs = -1;
        _tier = NetTier.offline;
      }
    } catch (_) {
      _rttMs = -1;
      _tier = NetTier.offline;
    } finally {
      _marcado = DateTime.now();
      dio.close();
    }
    return _tier;
  }

  /// Medición completa para el medidor de Ajustes: latencia y tier frescos.
  static Future<(NetTier, int)> measure() async {
    final NetTier t = await tier(force: true);
    return (t, _rttMs);
  }
}
