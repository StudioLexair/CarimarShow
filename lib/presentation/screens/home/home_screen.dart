import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/poster_image.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/entities/media_item.dart';
import '../../../domain/entities/watchlist_item.dart';
import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/media_providers.dart';
import '../../providers/watchlist_providers.dart';
import '../../widgets/demo_mode_banner.dart';
import '../../widgets/hero_backdrop.dart';
import '../../widgets/media_carousel.dart';
import '../../widgets/promo_banner.dart';

/// Portada: héroe rotatorio + carruseles por categoría.
///
/// Todo se resuelve en paralelo en [homeFeedProvider]. Si un carrusel falla se
/// muestra el resto, así un endpoint caído no deja la portada en blanco.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) =>
      ref.read(homeFeedProvider.notifier).refresh();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<HomeFeed> feed = ref.watch(homeFeedProvider);
    final AppUser? user = ref.watch(currentUserProvider);

    // Un saludo personalizado hace que la portada se sienta propia de cada
    // cuenta, y cuesta muy poco.
    final String greeting = _greeting(user?.displayName);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        color: AppColors.crimson,
        backgroundColor: context.pal.surfaceHigh,
        child: feed.when(
          loading: () => const _HomeSkeleton(),
          error: (Object error, StackTrace stackTrace) => _HomeError(
            error: error,
            onRetry: () => ref.invalidate(homeFeedProvider),
          ),
          data: (HomeFeed data) => _HomeContent(
            feed: data,
            greeting: greeting,
            onRefresh: () => _refresh(ref),
          ),
        ),
      ),
    );
  }

  static String _greeting(String? name) {
    final int hour = DateTime.now().hour;
    final String part = switch (hour) {
      < 6 => 'Buenas noches',
      < 13 => 'Buenos días',
      < 21 => 'Buenas tardes',
      _ => 'Buenas noches',
    };
    if (name == null || name.trim().isEmpty) return part;
    final String first = name.trim().split(RegExp(r'\s+')).first;
    return '$part, $first';
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({
    required this.feed,
    required this.greeting,
    required this.onRefresh,
  });

  final HomeFeed feed;
  final String greeting;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // «Continuar viendo» solo tiene sentido si hay algo a medias.
    final List<WatchlistItem> continuing = ref.watch(continueWatchingProvider);

    // El héroe se reduce en pantallas anchas para no comerse toda la altura.
    final double heroHeight = context.isCompact
        ? 440
        : (context.screenClass == ScreenClass.medium ? 420 : 380);

    // Se toman pocos títulos para el carrusel principal: demasiados hacen que
    // el usuario tarde mucho en llegar al resto de secciones.
    final List<MediaItem> heroes = feed.trending
        .take(6)
        .toList(growable: false);

    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          floating: true,
          snap: false,
          backgroundColor: context.pal.background.withValues(alpha: 0.86),
          surfaceTintColor: Colors.transparent,
          titleSpacing: 16,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/brand/logo.jpeg',
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 9),
              const Text(
                'CarimarShow',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Buscar',
              icon: const Icon(Icons.search_rounded),
              onPressed: () => context.push('/search'),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: 'Perfil',
                icon: const Icon(Icons.person_outline_rounded),
                onPressed: () => context.push('/profile'),
              ),
            ),
          ],
        ),

        const SliverToBoxAdapter(child: DemoModeBanner()),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(greeting, style: context.text.titleSmall),
          ),
        ),

        if (heroes.isNotEmpty)
          SliverToBoxAdapter(
            child: HeroBackdrop(items: heroes, height: heroHeight),
          ),

        if (continuing.isNotEmpty)
          SliverToBoxAdapter(
            child: BackdropCarousel(
              title: 'Continuar viendo',
              items: continuing
                  .map((WatchlistItem i) => i.media)
                  .toList(growable: false),
              subtitleBuilder: (MediaItem item) {
                final WatchlistItem? entry = continuing
                    .where((WatchlistItem i) => i.key == item.uniqueKey)
                    .firstOrNull;
                return entry?.progressPercent == null
                    ? 'Sin terminar'
                    : '${entry!.progressPercent}% visto';
              },
              progressBuilder: (MediaItem item) {
                final WatchlistItem? entry = continuing
                    .where((WatchlistItem i) => i.key == item.uniqueKey)
                    .firstOrNull;
                final int? percent = entry?.progressPercent;
                return percent == null ? null : percent / 100;
              },
            ),
          ),

        const SliverToBoxAdapter(child: PromoBanner()),

        SliverToBoxAdapter(
          child: MediaCarousel(
            title: 'Lo mejor de hoy',
            items:
                ref.watch(trendingTodayProvider).value ?? const <MediaItem>[],
            showTypeTag: true,
          ),
        ),

        SliverToBoxAdapter(
          child: MediaCarousel(
            title: 'Lo mejor de la semana',
            items: ref.watch(trendingWeekProvider).value ?? const <MediaItem>[],
            showTypeTag: true,
          ),
        ),

        SliverToBoxAdapter(
          child: MediaCarousel(
            title: 'Tendencias de la semana',
            items: feed.trending,
            showTypeTag: true,
            onSeeAll: () => context.go('/movies'),
          ),
        ),

        SliverToBoxAdapter(
          child: MediaCarousel(
            title: 'Películas populares',
            items: feed.popularMovies,
            onSeeAll: () => context.go('/movies'),
          ),
        ),

        SliverToBoxAdapter(
          child: MediaCarousel(
            title: 'Series populares',
            items: feed.popularSeries,
            onSeeAll: () => context.go('/series'),
          ),
        ),

        SliverToBoxAdapter(
          child: MediaCarousel(
            title: 'Próximos estrenos',
            items: feed.upcoming,
            subtitle: 'Lo que llega pronto',
            onSeeAll: () => context.go('/movies'),
          ),
        ),

        SliverToBoxAdapter(
          child: MediaCarousel(
            title: 'Mejor valoradas',
            subtitle: 'Películas con más nota',
            items: feed.topRatedMovies,
            onSeeAll: () => context.go('/movies'),
          ),
        ),

        SliverToBoxAdapter(
          child: MediaCarousel(
            title: 'Series en emisión',
            items: feed.onTheAir,
            onSeeAll: () => context.go('/series'),
          ),
        ),

        SliverToBoxAdapter(
          child: MediaCarousel(
            title: 'Series mejor valoradas',
            items: feed.topRatedSeries,
            onSeeAll: () => context.go('/series'),
          ),
        ),

        const SliverToBoxAdapter(child: _FooterAttribution()),
      ],
    );
  }
}

/// Atribución obligatoria de TMDB más el año en curso.
class _FooterAttribution extends ConsumerWidget {
  const _FooterAttribution();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isDemo = ref.watch(demoModeProvider);
    if (isDemo) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Text(
          'Catálogo ficticio de demostración. Ningún título mostrado existe.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            height: 1.5,
            color: context.pal.textDisabled,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        children: <Widget>[
          const Text(
            'Este producto usa la API de TMDB pero no está avalado ni '
            'certificado por TMDB.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: context.pal.textDisabled,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'CarimarShow · ${Formatters.year(DateTime.now())}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.pal.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

/// Esqueleto de la portada mientras carga.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        ShimmerBox(height: context.isCompact ? 440 : 380, borderRadius: 0),
        const SizedBox(height: 20),
        const MediaCarouselSkeleton(title: 'Tendencias de la semana'),
        const MediaCarouselSkeleton(title: 'Películas populares'),
        const MediaCarouselSkeleton(title: 'Series populares'),
        const SizedBox(height: 40),
      ],
    );
  }
}

/// Error global de la portada: solo aparece si fallaron TODOS los carruseles.
class _HomeError extends StatelessWidget {
  const _HomeError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // Se envuelve en LayoutBuilder+SingleChildScrollView para que
    // RefreshIndicator siga funcionando también en el estado de error.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: AppErrorView(error: error, onRetry: onRetry),
              ),
            ),
          ),
    );
  }
}
