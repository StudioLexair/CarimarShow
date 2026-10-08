/// Jerarquía de errores de dominio de la aplicación.
///
/// La capa de datos traduce los errores de transporte (Dio, Supabase) a estos
/// tipos, para que la UI pueda mostrar mensajes útiles sin conocer detalles de
/// la red y sin filtrar información interna al usuario.
library;

/// Categorías de fallo, usadas para elegir icono y mensaje.
enum AppFailureKind {
  /// Sin red, DNS caído, tiempo de espera agotado.
  network,

  /// 401/403: credenciales ausentes, inválidas o revocadas.
  unauthorized,

  /// 404: el recurso no existe.
  notFound,

  /// 429: se superó el límite de peticiones.
  rateLimit,

  /// 5xx: fallo del servidor remoto.
  server,

  /// 4xx distinto de los anteriores.
  client,

  /// Error de autenticación o de sesión.
  auth,

  /// Respuesta inesperada, JSON inválido, datos nulos obligatorios.
  parsing,

  /// Operación cancelada por el usuario o por navegación.
  cancelled,

  /// Cualquier otro caso.
  unknown,
}

/// Excepción base de la aplicación.
class AppException implements Exception {
  const AppException({
    required this.kind,
    required this.message,
    this.detail,
    this.statusCode,
    this.cause,
    this.stackTrace,
  });

  /// Tipo de fallo, para decidir cómo presentarlo.
  final AppFailureKind kind;

  /// Mensaje seguro para mostrar al usuario (ya localizado).
  final String message;

  /// Información técnica opcional, solo para logs.
  final String? detail;

  /// Código HTTP asociado, si procede.
  final int? statusCode;

  /// Excepción original que provocó esta.
  final Object? cause;

  /// Traza original, para diagnósticos.
  final StackTrace? stackTrace;

  /// `true` si tiene sentido ofrecer un botón de «reintentar».
  bool get isRetryable => switch (kind) {
    AppFailureKind.network ||
    AppFailureKind.rateLimit ||
    AppFailureKind.server ||
    AppFailureKind.unknown => true,
    _ => false,
  };

  /// `true` si el fallo es de configuración (credenciales) y no del usuario.
  bool get isConfigurationProblem => kind == AppFailureKind.unauthorized;

  @override
  String toString() =>
      'AppException(${kind.name}, status: $statusCode, message: $message'
      '${detail == null ? '' : ', detail: $detail'})';
}

/// Fallo de red o de tiempo de espera.
class NetworkException extends AppException {
  const NetworkException({
    super.message = 'Sin conexión',
    super.detail,
    super.cause,
    super.stackTrace,
  }) : super(kind: AppFailureKind.network);
}

/// Credenciales inválidas o ausentes.
class UnauthorizedException extends AppException {
  const UnauthorizedException({
    super.message = 'No autorizado',
    super.detail,
    super.cause,
    super.statusCode,
    super.stackTrace,
  }) : super(kind: AppFailureKind.unauthorized);
}

/// El recurso solicitado no existe.
class NotFoundException extends AppException {
  const NotFoundException({
    super.message = 'Recurso no encontrado',
    super.detail,
    super.cause,
    super.statusCode,
    super.stackTrace,
  }) : super(kind: AppFailureKind.notFound);
}

/// Se superó el límite de peticiones.
class RateLimitException extends AppException {
  const RateLimitException({
    super.message = 'Límite de peticiones superado',
    this.retryAfter,
    super.detail,
    super.cause,
    super.stackTrace,
  }) : super(kind: AppFailureKind.rateLimit, statusCode: 429);

  /// Segundos que pide el servidor esperar antes de reintentar.
  final Duration? retryAfter;
}

/// Fallo del servidor remoto.
class ServerException extends AppException {
  const ServerException({
    super.message = 'Error del servidor',
    super.statusCode,
    super.detail,
    super.cause,
    super.stackTrace,
  }) : super(kind: AppFailureKind.server);
}

/// Error de autenticación o sesión caducada.
class AuthException extends AppException {
  const AuthException({
    super.message = 'Error de autenticación',
    super.detail,
    super.cause,
    super.stackTrace,
  }) : super(kind: AppFailureKind.auth);
}

/// Respuesta con formato inesperado.
class ParsingException extends AppException {
  const ParsingException({
    super.message = 'Respuesta con formato inesperado',
    super.detail,
    super.cause,
    super.stackTrace,
  }) : super(kind: AppFailureKind.parsing);
}

/// Operación cancelada.
class CancelledException extends AppException {
  const CancelledException({
    super.message = 'Operación cancelada',
    super.cause,
    super.stackTrace,
  }) : super(kind: AppFailureKind.cancelled);
}
