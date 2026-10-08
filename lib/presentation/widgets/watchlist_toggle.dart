import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/media_id.dart';
import '../../domain/entities/media_item.dart';
import '../providers/watchlist_providers.dart';

/// Botón para guardar o quitar un título de «Mi lista».
///
/// Es un `ConsumerWidget` porque su aspecto depende del estado global de la
/// lista: cuando se marca desde la ficha, todos los botones de ese título (en la
/// portada, en la búsqueda, en similares) cambian a la vez.
class WatchlistToggle extends ConsumerWidget {
  const WatchlistToggle({
    required this.mediaId,
    required this.media,
    this.size = 40,
    this.style = WatchlistToggleStyle.overlay,
    super.key,
  });

  /// Botón grande con etiqueta, para la ficha de detalle.
  const WatchlistToggle.labeled({
    required this.mediaId,
    required this.media,
    super.key,
  }) : size = 44,
       style = WatchlistToggleStyle.labeled;

  final MediaId mediaId;

  /// Elemento completo, necesario para crear la entrada al guardar.
  final MediaItem media;

  final double size;
  final WatchlistToggleStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool saved = ref.watch(isInWatchlistProvider(mediaId));
    final bool pending = ref
        .watch(watchlistControllerProvider)
        .isPending(media.uniqueKey);

    void handleTap() {
      if (pending) return;
      ref.read(watchlistControllerProvider.notifier).toggle(media);
    }

    if (style == WatchlistToggleStyle.labeled) {
      return _LabeledToggle(saved: saved, pending: pending, onTap: handleTap);
    }

    return _OverlayToggle(
      saved: saved,
      pending: pending,
      size: size,
      onTap: handleTap,
    );
  }
}

enum WatchlistToggleStyle { overlay, labeled }

/// Círculo translúcido superpuesto al póster.
class _OverlayToggle extends StatelessWidget {
  const _OverlayToggle({
    required this.saved,
    required this.pending,
    required this.size,
    required this.onTap,
  });

  final bool saved;
  final bool pending;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: saved ? 'Quitar de Mi lista' : 'Añadir a Mi lista',
      child: Material(
        color: saved ? AppColors.crimson : Colors.black.withValues(alpha: 0.62),
        shape: CircleBorder(
          side: BorderSide(color: saved ? AppColors.crimson : Colors.white24),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: pending
                  ? SizedBox(
                      width: size * 0.42,
                      height: size * 0.42,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      saved ? Icons.check_rounded : Icons.add_rounded,
                      size: size * 0.55,
                      color: Colors.white,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón ancho con texto, para la barra de acciones de la ficha.
class _LabeledToggle extends StatelessWidget {
  const _LabeledToggle({
    required this.saved,
    required this.pending,
    required this.onTap,
  });

  final bool saved;
  final bool pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 50,
        child: saved
            ? FilledButton.icon(
                onPressed: pending ? null : onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.crimson.withValues(alpha: 0.16),
                  foregroundColor: AppColors.crimson,
                  side: const BorderSide(color: AppColors.crimson),
                  minimumSize: const Size(0, 50),
                ),
                icon: pending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, size: 20),
                label: Text(saved ? 'En Mi lista' : 'Mi lista'),
              )
            : OutlinedButton.icon(
                onPressed: pending ? null : onTap,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 50),
                  side: BorderSide(
                    color: context.pal.outline.withValues(alpha: 0.9),
                  ),
                ),
                icon: pending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded, size: 20),
                label: const Text('Mi lista'),
              ),
      ),
    );
  }
}
