import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/business_info.dart';
import '../../../core/utils/share_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/poster_image.dart';
import '../../../domain/entities/media_type.dart';
import '../../../domain/entities/watchlist_item.dart';
import '../../providers/watchlist_providers.dart';
import '../../widgets/brand_app_bar.dart';
import '../../widgets/demo_mode_banner.dart';

/// «Mi lista»: lo guardado por el usuario, con filtros y estados de seguimiento.
///
/// Los datos vienen de un `StreamProvider`, así que la pantalla se actualiza
/// sola cuando cambia algo desde otro dispositivo o desde otra pestaña.
class WatchlistScreen extends ConsumerWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<WatchlistItem>> async = ref.watch(watchlistProvider);
    final WatchlistStats stats = ref.watch(watchlistStatsProvider);
    final WatchlistStatus? filter = ref.watch(watchlistFilterProvider);
    final MediaType? typeFilter = ref.watch(_typeFilterProvider);

    // Aviso no bloqueante de fallos al guardar: se muestra y se consume.
    ref.listen(watchlistControllerProvider, (_, WatchlistUiState next) {
      final String? message = next.lastError ?? next.lastNotice;
      if (message == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: next.lastError != null
                ? AppColors.danger
                : AppColors.surfaceHighest,
            duration: const Duration(seconds: 2),
          ),
        );
      ref.read(watchlistControllerProvider.notifier).consumeMessages();
    });

    return Scaffold(
      appBar: BrandAppBar(
        actions: const <Widget>[_ShareListButton()],
        showSearch: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: <Widget>[
              _StatusFilters(stats: stats, selected: filter),
              _TypeFilters(selected: typeFilter),
            ],
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          const DemoModeBanner(),
          Expanded(
            child: async.when(
              loading: () => Padding(
                padding: EdgeInsets.all(context.gutter),
                child: const _WatchlistSkeleton(),
              ),
              error: (Object error, StackTrace st) => AppErrorView(
                error: error,
                onRetry: () => ref.invalidate(watchlistProvider),
              ),
              data: (List<WatchlistItem> all) {
                final List<WatchlistItem> items = _apply(
                  all,
                  status: filter,
                  type: typeFilter,
                );

                if (all.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.bookmark_add_outlined,
                    title: 'Tu lista está vacía',
                    message:
                        'Añade películas y series con el botón + para '
                        'tenerlas siempre a mano, en cualquier dispositivo.',
                    action: FilledButton.icon(
                      onPressed: () => context.go('/home'),
                      icon: const Icon(Icons.explore_rounded, size: 20),
                      label: const Text('Explorar catálogo'),
                    ),
                  );
                }

                if (items.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'Nada con estos filtros',
                    message:
                        'Tienes ${all.length} '
                        '${all.length == 1 ? 'título' : 'títulos'} guardados, '
                        'pero ninguno coincide con el filtro activo.',
                    action: OutlinedButton(
                      onPressed: () {
                        ref.read(watchlistFilterProvider.notifier).set(null);
                        ref.read(_typeFilterProvider.notifier).set(null);
                      },
                      child: const Text('Quitar filtros'),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(watchlistProvider),
                  color: AppColors.crimson,
                  backgroundColor: AppColors.surfaceHigh,
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      context.gutter,
                      12,
                      context.gutter,
                      32,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) =>
                        _WatchlistTile(item: items[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static List<WatchlistItem> _apply(
    List<WatchlistItem> all, {
    WatchlistStatus? status,
    MediaType? type,
  }) {
    Iterable<WatchlistItem> result = all;
    if (status != null) {
      result = result.where((WatchlistItem i) => i.status == status);
    }
    if (type != null) {
      result = result.where((WatchlistItem i) => i.type == type);
    }
    return result.toList(growable: false);
  }
}

/// Filtro por tipo de contenido dentro de Mi lista.
///
/// Se declara aquí porque es específico de esta pantalla; el de estado vive en
/// `watchlist_providers.dart` porque también lo usan los recuentos.
final _typeFilterProvider = NotifierProvider<_TypeFilterNotifier, MediaType?>(
  _TypeFilterNotifier.new,
);

class _TypeFilterNotifier extends Notifier<MediaType?> {
  @override
  MediaType? build() => null;

  void set(MediaType? type) => state = type;
}

class _StatusFilters extends ConsumerWidget {
  const _StatusFilters({required this.stats, required this.selected});

  final WatchlistStats stats;
  final WatchlistStatus? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<(WatchlistStatus?, String, int)> chips =
        <(WatchlistStatus?, String, int)>[
          (null, 'Todo', stats.total),
          (
            WatchlistStatus.planned,
            WatchlistStatus.planned.label,
            stats.planned,
          ),
          (
            WatchlistStatus.watching,
            WatchlistStatus.watching.label,
            stats.watching,
          ),
          (
            WatchlistStatus.completed,
            WatchlistStatus.completed.label,
            stats.completed,
          ),
        ];

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: chips.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final (WatchlistStatus? status, String label, int count) =
              chips[index];
          final bool isSelected = status == selected;
          return FilterChip(
            selected: isSelected,
            onSelected: (_) =>
                ref.read(watchlistFilterProvider.notifier).set(status),
            label: Text(
              count > 0 ? '$label · $count' : label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TypeFilters extends ConsumerWidget {
  const _TypeFilters({required this.selected});

  final MediaType? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const List<(MediaType?, String)> options = <(MediaType?, String)>[
      (null, 'Todo'),
      (MediaType.movie, 'Películas'),
      (MediaType.tv, 'Series'),
    ];

    return SizedBox(
      height: 44,
      child: Row(
        children: <Widget>[
          const SizedBox(width: 16),
          for (final (MediaType? type, String label) in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: type == selected,
                onSelected: (_) =>
                    ref.read(_typeFilterProvider.notifier).set(type),
                label: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: type == selected ? Colors.white : null,
                  ),
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
          const Spacer(),
          IconButton(
            tooltip: 'Vaciar lista',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.delete_sweep_outlined,
              size: 20,
              color: AppColors.textDisabled,
            ),
            onPressed: () => _confirmClear(context, ref),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Vaciar Mi lista'),
        content: const Text(
          'Se quitarán todos los títulos guardados. Esta acción no se puede '
          'deshacer.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(watchlistControllerProvider.notifier).clearAll();
    }
  }
}

/// Fila de la lista: póster, metadatos, progreso y selector de estado.
class _WatchlistTile extends ConsumerWidget {
  const _WatchlistTile({required this.item});

  final WatchlistItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool pending = ref
        .watch(watchlistControllerProvider)
        .isPending(item.key);

    return Material(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            context.push('/title/${item.type.apiValue}/${item.tmdbId}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox(
                  width: 62,
                  height: 93,
                  child: PosterImage(
                    imagePath: item.media.posterPath,
                    title: item.title,
                    seed: item.tmdbId,
                    size: 'w154',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.join(<String?>[
                        item.media.type.label,
                        Formatters.year(item.media.releaseDate),
                        if (item.media.hasVote)
                          '★ ${Formatters.vote(item.media.voteAverage)}',
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textDisabled,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((item.progressPercent ?? 0) > 0 &&
                        !item.isCompleted) ...<Widget>[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: (item.progressPercent! / 100).clamp(0, 1),
                          minHeight: 3.5,
                          backgroundColor: AppColors.surfaceHighest,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.crimson,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${item.progressPercent}% visto',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _StatusSelector(item: item, pending: pending),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Quitar de Mi lista',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textDisabled,
                ),
                onPressed: pending
                    ? null
                    : () => ref
                          .read(watchlistControllerProvider.notifier)
                          .remove(item.key, title: item.title),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Menú compacto para cambiar el estado de seguimiento.
class _StatusSelector extends ConsumerWidget {
  const _StatusSelector({required this.item, required this.pending});

  final WatchlistItem item;
  final bool pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<WatchlistStatus>(
      enabled: !pending,
      tooltip: 'Cambiar estado',
      position: PopupMenuPosition.under,
      color: AppColors.surfaceHighest,
      onSelected: (WatchlistStatus status) => ref
          .read(watchlistControllerProvider.notifier)
          .setStatus(item.key, status),
      itemBuilder: (BuildContext context) => WatchlistStatus.values
          .map(
            (WatchlistStatus status) => PopupMenuItem<WatchlistStatus>(
              value: status,
              height: 42,
              child: Row(
                children: <Widget>[
                  Icon(
                    _iconFor(status),
                    size: 17,
                    color: status == item.status
                        ? AppColors.crimson
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    status.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: status == item.status
                          ? AppColors.crimson
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (status == item.status) ...<Widget>[
                    const Spacer(),
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: AppColors.crimson,
                    ),
                  ],
                ],
              ),
            ),
          )
          .toList(growable: false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              _iconFor(item.status),
              size: 14,
              color: _colorFor(item.status),
            ),
            const SizedBox(width: 6),
            Text(
              item.status.label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: _colorFor(item.status),
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.expand_more_rounded,
              size: 15,
              color: AppColors.textDisabled,
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(WatchlistStatus status) => switch (status) {
    WatchlistStatus.planned => Icons.bookmark_border_rounded,
    WatchlistStatus.watching => Icons.play_circle_outline_rounded,
    WatchlistStatus.completed => Icons.check_circle_outline_rounded,
  };

  static Color _colorFor(WatchlistStatus status) => switch (status) {
    WatchlistStatus.planned => AppColors.textSecondary,
    WatchlistStatus.watching => AppColors.gold,
    WatchlistStatus.completed => AppColors.success,
  };
}

class _WatchlistSkeleton extends StatelessWidget {
  const _WatchlistSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) =>
          const ShimmerBox(height: 113, borderRadius: 14),
    );
  }
}


/// Botón de la barra que comparte la lista como texto plano.
///
/// Flujo que describió el cliente: el vendedor prepara la selección y se la
/// manda al dueño por WhatsApp. Se abre un diálogo para escribir una nota
/// final («pásate por el negocio antes de las 10») y el mensaje se compone
/// con la lista, la nota y los datos del negocio al pie.
class _ShareListButton extends ConsumerWidget {
  const _ShareListButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<WatchlistItem> items =
        ref.watch(watchlistProvider).value ?? const <WatchlistItem>[];
    if (items.isEmpty) return const SizedBox.shrink();

    return IconButton(
      tooltip: 'Compartir lista',
      icon: const Icon(Icons.share_outlined),
      onPressed: () => _confirm(context, items),
    );
  }

  Future<void> _confirm(BuildContext context, List<WatchlistItem> items) async {
    final TextEditingController note = TextEditingController();
    final String? texto = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Compartir tu lista'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${items.length} títulos. Añade una nota si quieres:'),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Ej.: paso a recogerlo el jueves por la tarde',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(note.text.trim()),
            child: const Text('Compartir'),
          ),
        ],
      ),
    );
    if (texto == null) return;

    final StringBuffer sb = StringBuffer('🎬 Mi lista de CarimarShow\n');
    for (final WatchlistItem i in items) {
      sb.writeln('• ${i.media.displayTitle} (${i.status.label})');
    }
    if (texto.isNotEmpty) sb.writeln('\n$texto');
    sb.writeln('\n${BusinessInfo.shareFooter}');

    final bool compartido = await ShareService.share(sb.toString());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(compartido
            ? 'Lista compartida'
            : 'Sin sheet nativo aquí: lista copiada al portapapeles'),
      ),
    );
  }
}
