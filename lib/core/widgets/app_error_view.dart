import 'package:flutter/material.dart';

import '../errors/app_exception.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Vista de error unificada.
///
/// Traduce el tipo de fallo a un icono, un título y una explicación accionable.
/// El objetivo es que el usuario sepa siempre **qué** ha pasado y **qué puede
/// hacer**, en lugar de ver una excepción en crudo.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    required this.error,
    this.onRetry,
    this.compact = false,
    this.title,
    super.key,
  });

  final Object? error;

  /// Si se aporta, se muestra el botón «Reintentar».
  final VoidCallback? onRetry;

  /// Versión reducida para huecos pequeños (un carrusel, una celda).
  final bool compact;

  /// Sobrescribe el título por defecto.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final AppException exception = _normalize(error);
    final _ErrorVisual visual = _visualFor(exception);

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          children: <Widget>[
            Icon(visual.icon, color: visual.color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(title ?? visual.title, style: context.text.titleSmall),
                  const SizedBox(height: 2),
                  Text(exception.message, style: context.text.bodySmall),
                ],
              ),
            ),
            if (onRetry != null && exception.isRetryable)
              IconButton(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Reintentar',
              ),
          ],
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: visual.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(visual.icon, color: visual.color, size: 34),
            ),
            const SizedBox(height: 22),
            Text(
              title ?? visual.title,
              textAlign: TextAlign.center,
              style: context.text.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(
              exception.message,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium,
            ),
            if (visual.hint != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                visual.hint!,
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(
                  color: context.pal.textDisabled,
                ),
              ),
            ],
            if (onRetry != null && exception.isRetryable) ...<Widget>[
              const SizedBox(height: 26),
              SizedBox(
                width: 200,
                child: FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('Reintentar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Convierte cualquier objeto de error en un [AppException].
  ///
  /// Riverpod 3 envuelve los fallos de proveedor en `ProviderException`; se
  /// desenvuelve para poder clasificar el error real.
  static AppException _normalize(Object? error) {
    if (error is AppException) return error;

    // `ProviderException` expone el error original en `.exception`.
    final Object? inner = _unwrap(error);
    if (inner is AppException) return inner;

    final String text = (inner ?? error)?.toString() ?? '';

    if (text.contains('SocketException') ||
        text.contains('Failed to fetch') ||
        text.contains('Connection') ||
        text.contains('Network')) {
      return const NetworkException();
    }

    return AppException(
      kind: AppFailureKind.unknown,
      message: text.isEmpty ? 'Error inesperado.' : text,
      cause: error,
    );
  }

  static Object? _unwrap(Object? error) {
    try {
      // Se accede por reflexión ligera: si el objeto tiene `exception`, se usa.
      // Evita importar Riverpod en la capa core.
      final dynamic dynamicError = error;
      return dynamicError?.exception as Object?;
    } catch (_) {
      return null;
    }
  }

  static _ErrorVisual _visualFor(AppException exception) {
    return switch (exception.kind) {
      AppFailureKind.network => const _ErrorVisual(
        icon: Icons.wifi_off_rounded,
        color: AppColors.warning,
        title: 'Sin conexión',
        hint: 'Comprueba tu conexión a internet y vuelve a intentarlo.',
      ),
      AppFailureKind.unauthorized => const _ErrorVisual(
        icon: Icons.key_off_rounded,
        color: AppColors.danger,
        title: 'Credenciales inválidas',
        hint:
            'Revisa TMDB_READ_TOKEN en tu archivo .env. '
            'Puede que el token esté caducado o revocado.',
      ),
      AppFailureKind.notFound => _ErrorVisual(
        icon: Icons.search_off_rounded,
        color: AppColors.accent,
        title: 'No encontrado',
        hint: 'El título puede haber sido retirado del catálogo.',
      ),
      AppFailureKind.rateLimit => _ErrorVisual(
        icon: Icons.hourglass_bottom_rounded,
        color: AppColors.warning,
        title: 'Demasiadas peticiones',
        hint: exception is RateLimitException && exception.retryAfter != null
            ? 'Vuelve a intentarlo en ${exception.retryAfter!.inSeconds} segundos.'
            : 'Espera unos segundos y vuelve a intentarlo.',
      ),
      AppFailureKind.server => const _ErrorVisual(
        icon: Icons.dns_rounded,
        color: AppColors.danger,
        title: 'Error del servidor',
        hint: 'Es un problema temporal del proveedor de datos.',
      ),
      AppFailureKind.client => const _ErrorVisual(
        icon: Icons.error_outline_rounded,
        color: AppColors.warning,
        title: 'Petición rechazada',
      ),
      AppFailureKind.auth => const _ErrorVisual(
        icon: Icons.lock_outline_rounded,
        color: AppColors.danger,
        title: 'Problema con tu sesión',
        hint: 'Prueba a cerrar sesión y volver a entrar.',
      ),
      AppFailureKind.parsing => const _ErrorVisual(
        icon: Icons.data_object_rounded,
        color: AppColors.warning,
        title: 'Datos inesperados',
        hint: 'La respuesta del servidor no tiene el formato esperado.',
      ),
      AppFailureKind.cancelled => _ErrorVisual(
        icon: Icons.cancel_outlined,
        color: AppColors.accent,
        title: 'Operación cancelada',
      ),
      AppFailureKind.unknown => _ErrorVisual(
        icon: Icons.report_gmailerrorred_rounded,
        color: AppColors.accent,
        title: 'Algo ha salido mal',
      ),
    };
  }
}

class _ErrorVisual {
  const _ErrorVisual({
    required this.icon,
    required this.color,
    required this.title,
    this.hint,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? hint;
}

/// Estado vacío genérico: sin resultados, lista vacía, etc.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.pal.surfaceHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.accent),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.text.titleLarge,
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium,
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
