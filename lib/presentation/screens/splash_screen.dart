import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../providers/core_providers.dart';

/// Pantalla de arranque.
///
/// Solo vive el tiempo que tarda en resolverse la sesión persistida. El router
/// redirige automáticamente a `/home` o `/login` en cuanto llega el primer
/// evento de autenticación, así que aquí no hay lógica de navegación.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isDemo = ref.watch(demoModeProvider);

    return Scaffold(
      backgroundColor: context.pal.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Image.asset(
                'assets/brand/logo.jpeg',
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 26),
            Text(
              Strings.appName,
              style: TextStyle(
                color: context.pal.textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                Strings.appTagline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.pal.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(height: 16),
            Text(
              isDemo ? 'Preparando catálogo local…' : 'Comprobando tu sesión…',
              style: TextStyle(
                color: context.pal.textDisabled,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
