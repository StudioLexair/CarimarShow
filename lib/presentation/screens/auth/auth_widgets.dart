/// Piezas visuales compartidas por las pantallas de acceso y registro.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Cabecera con logotipo, título y subtítulo.
class AuthHeader extends StatelessWidget {
  const AuthHeader({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          width: 62,
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[AppColors.crimsonLight, AppColors.crimsonDark],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Text(
            'S',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(title, style: context.text.displayMedium?.copyWith(fontSize: 30)),
        const SizedBox(height: 8),
        Text(subtitle, style: context.text.bodyMedium),
      ],
    );
  }
}

/// Mensaje de error en línea, dentro del formulario.
///
/// Se prefiere a un `SnackBar` porque permanece visible mientras el usuario
/// corrige los datos.
class InlineAuthError extends StatelessWidget {
  const InlineAuthError({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: context.pal.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Separador con texto, para el bloque «o continúa sin cuenta».
class AuthDivider extends StatelessWidget {
  const AuthDivider({this.label = 'o', super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: <Widget>[
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label, style: context.text.bodySmall),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

/// Aviso de que no hay backend y los datos se quedan en el dispositivo.
class NoBackendNotice extends StatelessWidget {
  const NoBackendNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.pal.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.pal.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.gold,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No hay backend configurado, así que tu sesión y Mi lista se '
              'guardan solo en este dispositivo. Para crear cuentas reales, '
              'configura SUPABASE_URL y SUPABASE_ANON_KEY (ver docs/SETUP.md).',
              style: context.text.bodySmall?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicador de envío, reutilizado en los botones de ambos formularios.
class SubmitSpinner extends StatelessWidget {
  const SubmitSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2.4,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }
}

/// Devuelve el error a mostrar cuando el usuario escribe una contraseña corta.
///
/// Se expone como función para que registro y cambio de contraseña compartan la
/// misma regla, en vez de duplicar el literal en dos sitios.
String? passwordHint(String value, {int minLength = 8}) {
  if (value.length < minLength) return 'Mínimo $minLength caracteres';
  return null;
}
