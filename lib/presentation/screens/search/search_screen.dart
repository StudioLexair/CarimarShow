import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/poster_image.dart';
import '../../../domain/entities/media_item.dart';
import '../../../domain/entities/media_type.dart';
import '../../../domain/repositories/media_repository.dart';
import '../../providers/media_providers.dart';
import '../../widgets/media_grid.dart';

/// Búsqueda con retardo y filtro por tipo.
///
/// El texto se escribe en un controlador local y solo se vuelca al proveedor
/// tras 400 ms sin teclear. Sin ese retardo se lanzaría una petición por cada
/// pulsación, que en TMDB se traduce en un 429 inmediato.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  /// Consulta que ya fue autocorregida, para no entrar en bucle.
  String? _corregidaDe;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;

  static const Duration _debounceDelay = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(searchQueryProvider);

    // Autocorrección de erratas: si una búsqueda se queda vacía y el léxico
    // local conoce un título parecido, se reescribe la consulta y se relanza,
    // avisando con un snack. «resindente evil» acaba buscando Resident Evil.
    ref.listen<String?>(searchSuggestionProvider, (String? prev, String? next) {
      if (next == null) return;
      final String actual = ref.read(searchQueryProvider);
      final bool vacia =
          ref.read(searchResultsProvider).value?.items.isEmpty ?? false;
      if (!vacia || _corregidaDe == actual) return;
      _corregidaDe = actual;
      _controller.text = next;
      ref.read(searchQueryProvider.notifier).set(next);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('¿Quisiste decir «$next»? Buscando eso.')),
        );
    });
    // El foco se pide tras el primer frame: hacerlo en initState compite con la
    // transición de ruta y en iOS el teclado puede no aparecer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (mounted) ref.read(searchQueryProvider.notifier).set(value);
    });
    // Se refresca el botón de limpiar al instante, sin esperar al retardo.
    setState(() {});
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    ref.read(searchQueryProvider.notifier).clear();
    setState(() {});
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final String query = ref.watch(searchQueryProvider);
    final MediaType? typeFilter = ref.watch(searchTypeProvider);
    final AsyncValue<MediaPage> results = ref.watch(searchResultsProvider);
    final AsyncValue<List<MediaItem>> suggestions = ref.watch(
      searchSuggestionsProvider,
    );

    final bool hasQuery = query.trim().length >= kMinSearchLength;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        automaticallyImplyLeading: true,
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          autofocus: false,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: Strings.searchHint,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            prefixIcon: const Icon(Icons.search_rounded, size: 22),
            prefixIconConstraints: const BoxConstraints(minWidth: 38),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Borrar',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: _clear,
                  )
                : null,
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          _TypeFilter(
            selected: typeFilter,
            onChanged: (MediaType? type) =>
                ref.read(searchTypeProvider.notifier).set(type),
          ),
          Expanded(
            child: Builder(
              builder: (BuildContext context) {
                // Sin texto suficiente: sugerencias basadas en tendencias.
                if (!hasQuery) {
                  return suggestions.when(
                    loading: () => Padding(
                      padding: EdgeInsets.all(context.gutter),
                      child: const PosterGridSkeleton(itemCount: 8),
                    ),
                    error: (Object error, StackTrace st) =>
                        AppErrorView(compact: true, error: error),
                    data: (List<MediaItem> items) => items.isEmpty
                        ? const EmptyStateView(
                            icon: Icons.search_rounded,
                            title: Strings.searchEmpty,
                            message:
                                'Busca por título, o explora el catálogo desde '
                                'las pestañas Películas y Series.',
                          )
                        : _SuggestionsList(items: items),
                  );
                }

                return results.when(
                  loading: () => Padding(
                    padding: EdgeInsets.all(context.gutter),
                    child: const PosterGridSkeleton(itemCount: 8),
                  ),
                  error: (Object error, StackTrace st) => AppErrorView(
                    error: error,
                    onRetry: () => ref.invalidate(searchResultsProvider),
                  ),
                  data: (MediaPage page) {
                    if (page.isEmpty) {
                      return EmptyStateView(
                        icon: Icons.search_off_rounded,
                        title: '${Strings.searchNoResults} «$query»',
                        message: typeFilter == null
                            ? 'Revisa la ortografía o prueba con un título más corto.'
                            : 'Prueba también sin el filtro de '
                                  '${typeFilter.pluralLabel.toLowerCase()}.',
                        action: typeFilter == null
                            ? null
                            : OutlinedButton(
                                onPressed: () => ref
                                    .read(searchTypeProvider.notifier)
                                    .set(null),
                                child: const Text('Quitar filtro'),
                              ),
                      );
                    }
                    return MediaGrid(
                      items: page.items,
                      showTypeTag: typeFilter == null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Selector Todo / Películas / Series.
class _TypeFilter extends StatelessWidget {
  const _TypeFilter({required this.selected, required this.onChanged});

  final MediaType? selected;
  final ValueChanged<MediaType?> onChanged;

  @override
  Widget build(BuildContext context) {
    const List<(MediaType?, String)> options = <(MediaType?, String)>[
      (null, 'Todo'),
      (MediaType.movie, 'Películas'),
      (MediaType.tv, 'Series'),
    ];

    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        itemCount: options.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final (MediaType? type, String label) = options[index];
          final bool isSelected = type == selected;
          return FilterChip(
            selected: isSelected,
            onSelected: (_) => onChanged(type),
            label: Text(
              label,
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

/// Sugerencias cuando el campo está vacío: tendencias del momento.
class _SuggestionsList extends StatelessWidget {
  const _SuggestionsList({required this.items});

  final List<MediaItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(context.gutter, 12, context.gutter, 6),
          child: Text(
            'Tendencias ahora',
            style: context.text.titleSmall?.copyWith(
              color: context.pal.textSecondary,
            ),
          ),
        ),
        for (final MediaItem item in items)
          ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: context.gutter),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 42,
                height: 63,
                child: PosterImage(
                  imagePath: item.posterPath,
                  title: item.displayTitle,
                  seed: item.id,
                  size: 'w92',
                ),
              ),
            ),
            title: Text(
              item.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${item.type.label} · ${item.year ?? '—'}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              FocusScope.of(context).unfocus();
              context.push('/title/${item.type.apiValue}/${item.id}');
            },
          ),
      ],
    );
  }
}
