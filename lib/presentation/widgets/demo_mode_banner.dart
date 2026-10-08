import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../providers/core_providers.dart';

/// Aviso discreto de que la app está en modo demo.
///
/// Solo aparece si no hay `TMDB_READ_TOKEN` configurado. Es importante: sin él,
/// alguien que arranque el proyecto vería títulos inventados y pensaría que la
/// app funciona mal, cuando en realidad solo le falta la credencial.
class DemoModeBanner extends ConsumerWidget {
  const DemoModeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isDemo = ref.watch(demoModeProvider);
    if (!isDemo) return const SizedBox.shrink();

    return Material(
      color: context.pal.surfaceHigh,
      child: InkWell(
        onTap: () => _showHelp(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.science_outlined,
                size: 16,
                color: AppColors.gold,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Modo demo: catálogo ficticio local. Toca para configurar TMDB.',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: context.pal.textSecondary,
                    height: 1.3,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: context.pal.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => const _DemoHelpSheet(),
    );
  }
}

class _DemoHelpSheet extends StatelessWidget {
  const _DemoHelpSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Salir del modo demo',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'La app funciona ahora con un catálogo ficticio incluido, para que '
              'puedas probarla sin configurar nada. Para ver películas y series '
              'reales necesitas una clave gratuita de TMDB.',
              style: TextStyle(fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 20),
            const _Step(
              number: 1,
              text:
                  'Crea una cuenta gratis en themoviedb.org y entra en '
                  'Settings → API.',
            ),
            const _Step(
              number: 2,
              text:
                  'Copia el archivo .env.example a .env en la raíz del proyecto.',
            ),
            const _Step(
              number: 3,
              text: 'Pega tu token en TMDB_READ_TOKEN y guarda.',
            ),
            const _Step(
              number: 4,
              text:
                  'Arranca la app con ./scripts/run.sh (o pasa '
                  '--dart-define=TMDB_READ_TOKEN=...).',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.pal.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.pal.outline),
              ),
              child: const Text(
                'flutter run --dart-define=TMDB_READ_TOKEN=tu_token',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  color: AppColors.gold,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'También puedes activar cuentas de usuario reales y sincronizar '
              'Mi lista entre dispositivos configurando Supabase. '
              'Todo el proceso está en docs/SETUP.md.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.crimson,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
