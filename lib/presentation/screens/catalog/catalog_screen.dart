import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/tmdb_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/poster_image.dart';
import '../../../domain/entities/genre.dart';
import '../../../domain/entities/media_type.dart';
import '../../providers/media_providers.dart';
import '../../widgets/brand_app_bar.dart';
import '../../widgets/demo_mode_banner.dart';
import '../../widgets/media_grid.dart';

/// Catálogo con pestañas (populares, mejor valoradas, estrenos) y filtros.
///
/// Sirve igual para películas y para series: solo cambia el [type]. Así no se
/// duplican dos pantallas que serían idénticas salvo por un parámetro.
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({required this.type, super.key});

  final MediaType type;

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: _feeds.length,
    vsync: this,
  );

  /// Pestañas disponibles. «Estrenos» cambia de sentido según el tipo:
  /// próximos estrenos en cine, series en emisión en TV.
  static const List<CatalogFeed> _feeds = <CatalogFeed>[
    CatalogFeed.popular,
    CatalogFeed.topRated,
    CatalogFeed.upcoming,
  ];

  final Set<int> _selectedGenres = <int>{};
  String? _sortBy;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _tabLabel(CatalogFeed feed) => switch (feed) {
    CatalogFeed.popular => 'Populares',
    CatalogFeed.topRated => 'Mejor valoradas',
    CatalogFeed.upcoming => widget.type.isTv ? 'En emisión' : 'Estrenos',
    CatalogFeed.nowPlaying => 'En cines',
    CatalogFeed.discover => 'Descubrir',
  };

  /// Consulta activa. Al ser un objeto con igualdad por valor, cada combinación
  /// de pestaña y filtros tiene su propio estado de paginación: cambiar de
  /// pestaña y volver conserva la posición y las páginas ya cargadas.
  CatalogQuery get _query => CatalogQuery(
    type: widget.type,
    feed: _feeds[_tabController.index],
    genreIds: _selectedGenres.toList(growable: false),
    sortBy: _sortBy,
  );

  void _toggleGenre(int id) {
    setState(() {
      if (!_selectedGenres.remove(id)) _selectedGenres.add(id);
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedGenres.clear();
      _sortBy = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final PagedMedia state = ref.watch(catalogProvider(_query));
    final AsyncValue<List<Genre>> genres = widget.type.isTv
        ? ref.watch(tvGenresProvider)
        : ref.watch(movieGenresProvider);

    return Scaffold(
      appBar: BrandAppBar(
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          onTap: (_) => setState(() {}),
          tabs: _feeds
              .map((CatalogFeed feed) => Tab(text: _tabLabel(feed)))
              .toList(growable: false),
        ),
      ),
      body: Column(
        children: <Widget>[
          const DemoModeBanner(),

          // ── Filtros ────────────────────────────────────────────────────
          genres.maybeWhen(
            data: (List<Genre> list) => _FilterBar(
              genres: list,
              selected: _selectedGenres,
              sortBy: _sortBy,
              onToggleGenre: _toggleGenre,
              onPickSort: _pickSort,
              onClear: _clearFilters,
            ),
            orElse: () => const SizedBox.shrink(),
          ),

          // ── Contenido ──────────────────────────────────────────────────
          Expanded(
            child: Builder(
              builder: (BuildContext context) {
                if (state.isLoading && state.items.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(context.gutter),
                    child: const PosterGridSkeleton(itemCount: 12),
                  );
                }

                if (state.hasError && state.items.isEmpty) {
                  return AppErrorView(
                    error: state.error,
                    onRetry: () =>
                        ref.read(catalogProvider(_query).notifier).load(),
                  );
                }

                if (state.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.movie_filter_outlined,
                    title: _selectedGenres.isEmpty
                        ? 'No hay ${widget.type.pluralLabel.toLowerCase()} aquí'
                        : 'Ningún título coincide con esos filtros',
                    message: _selectedGenres.isEmpty
                        ? 'Prueba con otra pestaña o vuelve más tarde.'
                        : 'Prueba a quitar algún género o a cambiar la ordenación.',
                    action: _selectedGenres.isEmpty
                        ? null
                        : OutlinedButton(
                            onPressed: _clearFilters,
                            child: const Text('Quitar filtros'),
                          ),
                  );
                }

                return Stack(
                  children: <Widget>[
                    RefreshIndicator(
                      onRefresh: () =>
                          ref.read(catalogProvider(_query).notifier).load(),
                      color: AppColors.crimson,
                      backgroundColor: context.pal.surfaceHigh,
                      child: MediaGrid(
                        items: state.items,
                        hasMore: state.hasMore,
                        isLoadingMore: state.isLoadingMore,
                        onLoadMore: () => ref
                            .read(catalogProvider(_query).notifier)
                            .loadMore(),
                      ),
                    ),

                    // Aviso no bloqueante si falla solo la paginación: se
                    // conserva lo ya cargado y se ofrece reintentar.
                    if (state.isLoadingMore && state.hasError)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 12,
                        child: Center(
                          child: Material(
                            color: context.pal.surfaceHighest,
                            borderRadius: BorderRadius.circular(999),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    size: 16,
                                    color: AppColors.warning,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'No se pudo cargar más',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => ref
                                        .read(catalogProvider(_query).notifier)
                                        .loadMore(),
                                    child: const Text('Reintentar'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSort() async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text('Ordenar por', style: context.text.titleMedium),
            ),
            // Se usa ListTile con marca en vez de RadioListTile: los parámetros
            // `groupValue`/`onChanged` de los Radio quedaron deprecados en
            // favor de RadioGroup, y esto evita la dependencia por completo.
            for (final String option in TmdbSortBy.all)
              ListTile(
                dense: true,
                onTap: () => Navigator.of(context).pop(option),
                leading: Icon(
                  (_sortBy ?? 'popularity.desc') == option
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 20,
                  color: (_sortBy ?? 'popularity.desc') == option
                      ? AppColors.crimson
                      : context.pal.textDisabled,
                ),
                title: Text(
                  TmdbSortBy.label(option),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _sortBy = picked);
  }
}

/// Barra horizontal de chips de género más el selector de ordenación.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.genres,
    required this.selected,
    required this.sortBy,
    required this.onToggleGenre,
    required this.onPickSort,
    required this.onClear,
  });

  final List<Genre> genres;
  final Set<int> selected;
  final String? sortBy;
  final ValueChanged<int> onToggleGenre;
  final VoidCallback onPickSort;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (genres.isEmpty) return const SizedBox.shrink();

    final bool hasFilters = selected.isNotEmpty || sortBy != null;

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: sortBy != null,
              onSelected: (_) => onPickSort(),
              avatar: Icon(
                Icons.sort_rounded,
                size: 16,
                color: sortBy != null
                    ? Colors.white
                    : context.pal.textSecondary,
              ),
              label: Text(
                sortBy == null ? 'Orden' : TmdbSortBy.label(sortBy!),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: sortBy != null ? Colors.white : null,
                ),
              ),
            ),
          ),
          if (hasFilters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.close_rounded, size: 16),
                onPressed: onClear,
                label: const Text(
                  'Limpiar',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          for (final Genre genre in genres)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: selected.contains(genre.id),
                onSelected: (_) => onToggleGenre(genre.id),
                label: Text(
                  genre.name,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: selected.contains(genre.id) ? Colors.white : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
