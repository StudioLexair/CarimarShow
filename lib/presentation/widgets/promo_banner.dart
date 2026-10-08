import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../providers/settings_providers.dart';

/// Banner promocional de la portada, activable desde el perfil.
///
/// El cliente lo describió como «un banner promocionante que lo puedes poner
/// o no puedes poner»: por eso el texto es editable y el cierre (la ×)
/// desactiva el banner, que es lo que cualquier dueño esperaría de ese botón.
class PromoBanner extends ConsumerWidget {
  const PromoBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PromoSettings promo = ref.watch(promoSettingsProvider);
    if (!promo.enabled || promo.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/negocio'),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[AppColors.accent, AppColors.accentDeep],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.campaign_outlined, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      promo.text,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Ocultar banner',
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: () =>
                        ref.read(promoSettingsProvider.notifier).setEnabled(false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
