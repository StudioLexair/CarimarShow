import 'package:flutter/material.dart';

import '../../core/utils/responsive.dart';
import '../../core/widgets/poster_image.dart';
import '../../domain/entities/media_item.dart';
import 'media_poster_card.dart';

/// Rejilla de pósters que se adapta al ancho disponible.
///
/// El número de columnas sale de [ResponsiveX.posterColumns], así la misma
/// pantalla muestra 2 columnas en un móvil y 7 en un monitor grande sin código
/// específico por plataforma.
class MediaGrid extends StatelessWidget {
  const MediaGrid({
    required this.items,
    this.showTypeTag = false,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.onLoadMore,
    this.spacing = 12,
    this.padding,
    this.physics,
    this.shrinkWrap = false,
    super.key,
  });

  final List<MediaItem> items;
  final bool showTypeTag;

  /// Si hay más páginas, se añade una celda final con el indicador de carga.
  final bool hasMore;
  final bool isLoadingMore;

  /// Se invoca cuando el usuario se acerca al final de la lista.
  final VoidCallback? onLoadMore;

  final double spacing;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    // La última celda es el disparador de paginación, solo si hay más.
    final int itemCount = items.length + (hasMore ? 1 : 0);

    return GridView.builder(
      padding: padding ?? EdgeInsets.all(context.gutter),
      physics: physics,
      shrinkWrap: shrinkWrap,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.posterColumns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        // 2:3 del póster más el hueco para título y año.
        childAspectRatio: 0.56,
      ),
      itemCount: itemCount,
      itemBuilder: (BuildContext context, int index) {
        if (index >= items.length) {
          return _LoadMoreCell(isLoading: isLoadingMore, onRetry: onLoadMore);
        }
        return MediaPosterCard(item: items[index], showTypeTag: showTypeTag);
      },
    );
  }
}

/// Celda final de la rejilla: dispara la carga de la siguiente página.
class _LoadMoreCell extends StatefulWidget {
  const _LoadMoreCell({required this.isLoading, this.onRetry});

  final bool isLoading;
  final VoidCallback? onRetry;

  @override
  State<_LoadMoreCell> createState() => _LoadMoreCellState();
}

class _LoadMoreCellState extends State<_LoadMoreCell> {
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    // Se programa tras el primer frame: llamar a un callback del padre durante
    // `initState` provocaría un `setState` sobre un widget aún en construcción.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoad());
  }

  @override
  void didUpdateWidget(covariant _LoadMoreCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading && !widget.isLoading) _triggered = false;
    _maybeLoad();
  }

  void _maybeLoad() {
    if (!mounted || _triggered || widget.isLoading) return;
    _triggered = true;
    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    return const ShimmerBox(borderRadius: 14);
  }
}
