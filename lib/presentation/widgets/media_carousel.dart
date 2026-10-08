import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/poster_image.dart';
import '../../core/widgets/section_header.dart';
import '../../domain/entities/media_item.dart';
import 'media_poster_card.dart';

/// Carrusel horizontal de pósters con cabecera de sección.
///
/// Incluye `cacheExtent` para precargar las tarjetas adyacentes y que el
/// desplazamiento no muestre huecos en blanco.
class MediaCarousel extends StatelessWidget {
  const MediaCarousel({
    required this.items,
    required this.title,
    this.subtitle,
    this.itemWidth = 132,
    this.showTypeTag = false,
    this.onSeeAll,
    this.emptyMessage,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
    super.key,
  });

  final List<MediaItem> items;
  final String title;
  final String? subtitle;
  final double itemWidth;
  final bool showTypeTag;
  final VoidCallback? onSeeAll;

  /// Si se aporta y la lista viene vacía, se muestra este mensaje en vez de
  /// ocultar la sección entera. Útil en listas filtradas.
  final String? emptyMessage;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && emptyMessage == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionHeader(
          title: title,
          subtitle: subtitle,
          actionLabel: items.length > 6 ? 'Ver todo' : null,
          onAction: onSeeAll,
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              emptyMessage ?? 'Nada por aquí todavía.',
              style: TextStyle(color: context.pal.textDisabled, fontSize: 13),
            ),
          )
        else
          SizedBox(
            height: itemWidth * 1.5 + 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              // `cacheExtent` está deprecado en favor de `scrollCacheExtent`,
              // pero el tipo de repuesto `ScrollCacheExtent` NO se exporta
              // públicamente (flutter/flutter#189347): no hay forma de
              // construirlo desde código de aplicación. Se mantiene la
              // propiedad deprecada —sigue funcionando— hasta que Flutter
              // arregle la exportación. Es un info de analizador, no un warning.
              // ignore: deprecated_member_use
              cacheExtent: itemWidth * 3,
              itemCount: items.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(width: 12),
              itemBuilder: (BuildContext context, int index) => MediaPosterCard(
                item: items[index],
                width: itemWidth,
                showTypeTag: showTypeTag,
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Carrusel de esqueletos, para el estado de carga de la portada.
class MediaCarouselSkeleton extends StatelessWidget {
  const MediaCarouselSkeleton({
    this.title,
    this.itemCount = 6,
    this.itemWidth = 132,
    super.key,
  });

  final String? title;
  final int itemCount;
  final double itemWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (title != null) SectionHeader(title: title!),
        SizedBox(
          height: itemWidth * 1.5 + 54,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const NeverScrollableScrollPhysics(),
            itemCount: itemCount,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: 12),
            itemBuilder: (BuildContext context, int index) => SizedBox(
              width: itemWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: ShimmerBox(borderRadius: 14)),
                  const SizedBox(height: 8),
                  const ShimmerBox(height: 12, width: 96),
                  const SizedBox(height: 6),
                  const ShimmerBox(height: 10, width: 64),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Carrusel de fondos 16:9, usado en «Continuar viendo».
class BackdropCarousel extends StatelessWidget {
  const BackdropCarousel({
    required this.title,
    required this.items,
    this.subtitleBuilder,
    this.progressBuilder,
    super.key,
  });

  final String title;
  final List<MediaItem> items;

  /// Genera el subtítulo de cada tarjeta (p. ej. «T2 · 45 %»).
  final String? Function(MediaItem item)? subtitleBuilder;

  /// Genera el progreso 0–1 de cada tarjeta.
  final double? Function(MediaItem item)? progressBuilder;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionHeader(title: title),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: 12),
            itemBuilder: (BuildContext context, int index) {
              final MediaItem item = items[index];
              return MediaBackdropCard(
                item: item,
                width: 240,
                subtitle: subtitleBuilder?.call(item),
                progress: progressBuilder?.call(item),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
