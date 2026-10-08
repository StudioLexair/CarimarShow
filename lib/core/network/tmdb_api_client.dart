import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../cache/catalog_cache.dart';
import '../config/app_config.dart';
import '../constants/app_strings.dart';
import '../constants/tmdb_constants.dart';
import '../errors/app_exception.dart';

/// Cliente HTTP afinado para la API de TMDB.
///
/// Responsabilidades:
///  * Inyectar autenticación (Bearer v4 o `api_key` v3) e idioma/región.
///  * Convertir cualquier fallo de transporte en un [AppException] tipado.
///  * Extraer de forma uniforme las listas de las respuestas paginadas.
class TmdbApiClient {
  TmdbApiClient({required this.config, Dio? dio, this.cache})
      : _dio = dio ?? Dio() {
    _dio
      ..options.baseUrl = Tmdb.baseUrl
      ..options.connectTimeout = Tmdb.timeout
      ..options.receiveTimeout = Tmdb.timeout
      ..options.headers = <String, dynamic>{
        'Accept': 'application/json',
        if (config.tmdbReadToken.isNotEmpty)
          'Authorization': 'Bearer ${config.tmdbReadToken}',
      }
      ..interceptors.addAll(<Interceptor>[
        _LanguageInterceptor(config),
        const _LogInterceptor(),
      ]);
  }

  /// Configuración resuelta de la aplicación.
  final AppConfig config;
  final Dio _dio;

  /// Caché en disco de respuestas. Si es `null`, el cliente funciona exactamente
  /// como antes: red pura sin copia local.
  final CatalogCache? cache;

  /// Parámetros comunes. Si solo hay `api_key` (v3), se manda como query param.
  Map<String, dynamic> _baseQuery([Map<String, dynamic>? extra]) =>
      <String, dynamic>{
        if (config.tmdbReadToken.isEmpty && config.tmdbApiKey.isNotEmpty)
          'api_key': config.tmdbApiKey,
        ...?extra,
      };

  /// Petición GET que devuelve el JSON descodificado.
  ///
  /// Con caché activa es *cache-first en el fallo*: se intenta siempre la red
  /// (para tener lo más fresco posible) y, si la red no responde, se sirve la
  /// última copia buena del disco. Es exactamente la regla que pidió el
  /// cliente: «¿hay internet? busca y cachea; ¿no hay? busca local».
  Future<dynamic> getJson(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    final String? cacheKey = cache == null ? null : _cacheKey(path, query);
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        path,
        queryParameters: _baseQuery(query),
        cancelToken: cancelToken,
      );
      if (cacheKey != null) {
        // Guardar no debe retrasar la respuesta que ya llegó bien.
        unawaited(cache!.write(cacheKey, jsonEncode(response.data)));
      }
      return response.data;
    } on DioException catch (error, stackTrace) {
      final dynamic stale = await _stale(cacheKey, error);
      if (stale != null) return stale;
      throw mapDioException(error, stackTrace);
    } on AppException {
      rethrow;
    } catch (error, stackTrace) {
      throw AppException(
        kind: AppFailureKind.unknown,
        message: Strings.errorUnknown,
        detail: error.toString(),
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Clave de caché: ruta + parámetros ordenados + idioma. El idioma entra en
  /// la clave porque TMDB devuelve títulos y sinopsis traducidos: una copia en
  /// es-ES no sirve para una sesión en en-US.
  String _cacheKey(String path, Map<String, dynamic>? query) {
    final List<MapEntry<String, dynamic>> params =
        (query?.entries.toList() ?? <MapEntry<String, dynamic>>[])
          ..sort((MapEntry<String, dynamic> a, MapEntry<String, dynamic> b) =>
              a.key.compareTo(b.key));
    return '${config.language}|$path|${params.map((MapEntry<String, dynamic> e) => '${e.key}=${e.value}').join('&')}';
  }

  /// Copia en disco cuando el fallo es de conectividad o del servidor.
  ///
  /// Un 404 o un 401 NO se sirven desde caché: son respuestas reales que la UI
  /// debe traducir («no existe», «revisa tu token»). Solo se degrada ante
  /// ausencia de red, timeouts, 429 o 5xx.
  Future<dynamic> _stale(String? cacheKey, DioException error) async {
    if (cacheKey == null) return null;
    final int status = error.response?.statusCode ?? 0;
    final bool offline = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError ||
      DioExceptionType.unknown => true,
      DioExceptionType.badResponse => status == 429 || status >= 500,
      _ => false,
    };
    if (!offline) return null;
    final String? raw = await cache!.read(cacheKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  /// GET que devuelve `{}` garantizado como objeto JSON.
  Future<Map<String, dynamic>> getObject(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    final dynamic data = await getJson(
      path,
      query: query,
      cancelToken: cancelToken,
    );
    if (data is Map<String, dynamic>) return data;
    throw ParsingException(
      detail:
          'Se esperaba un objeto JSON en "$path" y se obtuvo '
          '${data.runtimeType}',
    );
  }

  /// GET que devuelve solo la lista `results`, sin metadatos de paginación.
  Future<List<Map<String, dynamic>>> getList(
    String path, {
    Map<String, dynamic>? query,
    String resultsKey = 'results',
    CancelToken? cancelToken,
  }) async {
    final PaginatedJson page = await getPaginated(
      path,
      query: query,
      resultsKey: resultsKey,
      cancelToken: cancelToken,
    );
    return page.results;
  }

  /// GET paginado con metadatos de paginación.
  Future<PaginatedJson> getPaginated(
    String path, {
    Map<String, dynamic>? query,
    String resultsKey = 'results',
    CancelToken? cancelToken,
  }) async {
    final Map<String, dynamic> data = await getObject(
      path,
      query: query,
      cancelToken: cancelToken,
    );
    final dynamic raw = data[resultsKey];
    final List<Map<String, dynamic>> results = raw is List
        ? raw.whereType<Map<String, dynamic>>().toList(growable: false)
        : const <Map<String, dynamic>>[];

    return PaginatedJson(
      results: results,
      page: _asInt(data['page']) ?? 1,
      totalPages: _asInt(data['total_pages']),
      totalResults: _asInt(data['total_results']),
    );
  }

  /// Traduce un [DioException] a la jerarquía de errores de la app.
  static AppException mapDioException(
    DioException error,
    StackTrace stackTrace,
  ) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => NetworkException(
        message: Strings.errorNetwork,
        detail: 'Tiempo de espera agotado: ${error.message}',
        cause: error,
        stackTrace: stackTrace,
      ),
      DioExceptionType.transformTimeout ||
      DioExceptionType.connectionError => NetworkException(
        message: Strings.errorNetwork,
        detail: error.message,
        cause: error,
        stackTrace: stackTrace,
      ),
      DioExceptionType.cancel => CancelledException(
        cause: error,
        stackTrace: stackTrace,
      ),
      DioExceptionType.badCertificate => NetworkException(
        message: Strings.errorNetwork,
        detail: 'Certificado no válido',
        cause: error,
        stackTrace: stackTrace,
      ),
      DioExceptionType.badResponse => _mapStatus(error.response, stackTrace),
      DioExceptionType.unknown =>
        error.response != null
            ? _mapStatus(error.response, stackTrace)
            : NetworkException(
                message: Strings.errorNetwork,
                detail: error.message,
                cause: error,
                stackTrace: stackTrace,
              ),
    };
  }

  static AppException _mapStatus(
    Response<dynamic>? response,
    StackTrace stackTrace,
  ) {
    final int status = response?.statusCode ?? 0;
    final String detail = _describe(response);

    return switch (status) {
      401 || 403 => UnauthorizedException(
        message: Strings.errorUnauthorized,
        statusCode: status,
        detail: detail,
        cause: response,
        stackTrace: stackTrace,
      ),
      404 => NotFoundException(
        message: Strings.errorNotFound,
        statusCode: status,
        detail: detail,
        cause: response,
        stackTrace: stackTrace,
      ),
      429 => RateLimitException(
        message: Strings.errorRateLimit,
        detail: detail,
        retryAfter: _retryAfter(response),
        cause: response,
        stackTrace: stackTrace,
      ),
      >= 500 => ServerException(
        message: Strings.errorServer,
        statusCode: status,
        detail: detail,
        cause: response,
        stackTrace: stackTrace,
      ),
      _ => AppException(
        kind: AppFailureKind.client,
        message: Strings.errorUnknown,
        statusCode: status,
        detail: detail,
        cause: response,
        stackTrace: stackTrace,
      ),
    };
  }

  /// TMDB incluye un cuerpo JSON con `status_message` incluso en los errores.
  static String _describe(Response<dynamic>? response) {
    if (response == null) return 'Respuesta vacía';
    final dynamic data = response.data;
    if (data is Map<String, dynamic>) {
      final Object? message = data['status_message'] ?? data['message'];
      if (message != null) {
        return '${response.statusCode}: $message (código ${data['status_code']})';
      }
    }
    return 'HTTP ${response.statusCode}';
  }

  static Duration? _retryAfter(Response<dynamic>? response) {
    final String? raw = response?.headers.value('retry-after');
    final int? seconds = raw == null ? null : int.tryParse(raw);
    return seconds == null ? null : Duration(seconds: seconds);
  }

  static int? _asInt(Object? value) => switch (value) {
    final int i => i,
    final num n => n.toInt(),
    final String s => int.tryParse(s),
    _ => null,
  };

  /// Libera conexiones. Se llama al cerrar la app o en tests.
  void close() => _dio.close(force: true);
}

/// Resultado paginado en crudo, antes de mapear a entidades.
class PaginatedJson {
  const PaginatedJson({
    required this.results,
    required this.page,
    this.totalPages,
    this.totalResults,
  });

  final List<Map<String, dynamic>> results;
  final int page;
  final int? totalPages;
  final int? totalResults;

  bool get hasMore =>
      totalPages == null ? results.isNotEmpty : page < totalPages!;

  bool get isEmpty => results.isEmpty;
}

/// Añade `language` y `region` a todas las peticiones de catálogo.
class _LanguageInterceptor extends Interceptor {
  const _LanguageInterceptor(this.config);

  /// Configuración resuelta de la aplicación.
  final AppConfig config;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.queryParameters
      ..putIfAbsent('language', () => config.language)
      ..putIfAbsent('region', () => config.region);
    handler.next(options);
  }
}

/// Log mínimo y seguro: registra ruta y estado, nunca cabeceras ni tokens.
class _LogInterceptor extends Interceptor {
  const _LogInterceptor();

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _emit('← ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _emit(
      '✕ ${err.response?.statusCode ?? '-'} '
      '${err.requestOptions.path} · ${err.type.name}',
    );
    handler.next(err);
  }

  static void _emit(String line) {
    if (kDebugMode) debugPrint('[CarimarShow·http] $line');
  }
}

/// Descodifica una cadena JSON garantizando un objeto en la raíz.
Map<String, dynamic> decodeJsonObject(String source) {
  final dynamic parsed = jsonDecode(source);
  if (parsed is! Map<String, dynamic>) {
    throw const ParsingException(
      detail: 'Se esperaba un objeto JSON en la raíz',
    );
  }
  return parsed;
}
