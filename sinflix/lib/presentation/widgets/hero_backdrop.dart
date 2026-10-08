import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/poster_image.dart';
import '../../domain/entities/media_id.dart';
import '../../domain/entities/media_item.dart';
import '../providers/media_providers.dart';
import '../providers/watchlist_providers.dart';
import 'rating_badge.dart';

/// Carrusel principal de la portada: fondo grande, título y acciones.
///
/// Avanza solo cada pocos segundos y se detiene en cuanto el usuario lo toca o
/// la pantalla deja de ser visible (para no gastar batería ni datos en segundo
/// plano).
class HeroBackdrop extends ConsumerStatefulWidget {
  const HeroBackdrop({
    required this.items,
    this.height = 460,
    this.autoAdvance = const Duration(seconds: 7),
    super.key,
  });

  final List<MediaItem> items;

  /// Altura total del bloque. En móvil se reduce desde el `LayoutBuilder`.
  final double height;

  final Duration autoAdvance;

  @override
  ConsumerState<HeroBackdrop> createState() => _HeroBackdropState();
}

class _HeroBackdropState extends ConsumerState<HeroBackdrop> {
  final PageController _controller = PageController(viewportFraction: 1);
  Timer? _timer;

  /// `false` en cuanto el usuario interactúa: a partir de ahí no se autoavanza.
  bool _userDriven = false;

  @override
  void initState() {
    super.initState();
    _scheduleAutoAdvance();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleAutoAdvance() {
    _timer?.cancel();
    if (widget.autoAdvance == Duration.zero) return;
    _timer = Timer.periodic(widget.autoAdvance, (_) {
      if (!mounted || _userDriven || widget.items.length < 2) return;
      // Se pausa si la app no está visible (cambio de pestaña, bloqueo…).
      final bool visible =
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (!visible) return;

      final int next = (ref.read(heroIndexProvider) + 1) % widget.items.length;
      if (_controller.hasClients) {
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 480),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _onPageChanged(int index) {
    ref.read(heroIndexProvider.notifier).set(index);
  }

  void _onUserScroll() {
    if (_userDriven) return;
    _userDriven = true;
    _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final int index = ref
        .watch(heroIndexProvider)
        .clamp(0, widget.items.length - 1);

    return SizedBox(
      height: widget.height,
      child: NotificationListener<ScrollNotification>(
        // Captura el gesto del usuario para cancelar el avance automático.
        onNotification: (ScrollNotification notification) {
          if (notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            _onUserScroll();
          }
          return false;
        },
        child: Stack(
          children: <Widget>[
            PageView.builder(
              controller: _controller,
              onPageChanged: _onPageChanged,
              itemCount: widget.items.length,
              itemBuilder: (BuildContext context, int i) =>
                  _HeroSlide(item: widget.items[i]),
            ),

            // Indicadores de página.
            if (widget.items.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: IgnorePointer(
                  child: _PageDots(count: widget.items.length, active: index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroSlide extends ConsumerWidget {
  const _HeroSlide({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MediaId id = mediaIdOf(item);
    final List<String> genres = ref.watch(itemGenreNamesProvider(item));
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        BackdropImage(
          imagePath: item.backdropPath ?? item.posterPath,
          title: item.displayTitle,
          seed: item.id,
        ),

        // Doble degradado: vertical para el texto inferior y lateral para que
        // los botones no compitan con la imagen.
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.backdropScrim),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                AppColors.background.withValues(alpha: 0.55),
                Colors.transparent,
              ],
            ),
          ),
        ),

        Positioned(
          left: 20,
          right: 20,
          bottom: 34 + bottomInset,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  MediaTypeTag(isTv: item.type.isTv),
                  if (item.hasVote) ...<Widget>[
                    const SizedBox(width: 10),
                    RatingBadge(voteAverage: item.voteAverage),
                    if (item.voteCount > 0) ...<Widget>[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${Formatters.voteCount(item.voteCount)} votos',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.9,
                  height: 1.1,
                ),
              ),
              if (genres.isNotEmpty || item.year != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  Formatters.join(<String?>[
                    if (item.year != null) '${item.year}',
                    ...genres.take(3),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.push(id.route),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 24),
                      label: const Text(
                        'Ver ficha',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _HeroWatchlistButton(item: item, id: id),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroWatchlistButton extends ConsumerWidget {
  const _HeroWatchlistButton({required this.item, required this.id});

  final MediaItem item;
  final MediaId id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool saved = ref.watch(isInWatchlistProvider(id));
    final bool pending = ref
        .watch(watchlistControllerProvider)
        .isPending(item.uniqueKey);

    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: pending
            ? null
            : () => ref.read(watchlistControllerProvider.notifier).toggle(item),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: pending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    saved ? Icons.check_rounded : Icons.add_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
          ),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    // Con muchas páginas los puntos dejan de ser útiles y ocupan espacio.
    final int shown = count > 8 ? 8 : count;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(shown, (int i) {
        final bool isActive = i == active % shown;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? AppColors.crimson : Colors.white38,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
