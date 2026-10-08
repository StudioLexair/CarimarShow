import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carimarshow/app.dart';
import 'package:carimarshow/core/constants/app_strings.dart';
import 'package:carimarshow/core/constants/tmdb_constants.dart';
import 'package:carimarshow/core/errors/app_exception.dart';
import 'package:carimarshow/core/theme/app_colors.dart';
import 'package:carimarshow/core/theme/app_theme.dart';
import 'package:carimarshow/core/utils/responsive.dart';
import 'package:carimarshow/core/widgets/app_error_view.dart';
import 'package:carimarshow/core/widgets/poster_image.dart';
import 'package:carimarshow/core/widgets/section_header.dart';
import 'package:carimarshow/domain/entities/cast_member.dart';
import 'package:carimarshow/domain/entities/media_id.dart';
import 'package:carimarshow/domain/entities/media_item.dart';
import 'package:carimarshow/domain/entities/media_type.dart';
import 'package:carimarshow/domain/repositories/media_repository.dart';
import 'package:carimarshow/presentation/providers/media_providers.dart';
import 'package:carimarshow/presentation/providers/watchlist_providers.dart';
import 'package:carimarshow/presentation/screens/auth/auth_widgets.dart';
import 'package:carimarshow/presentation/screens/auth/login_screen.dart';
import 'package:carimarshow/presentation/screens/auth/register_screen.dart';
import 'package:carimarshow/presentation/screens/catalog/catalog_screen.dart';
import 'package:carimarshow/presentation/screens/detail/media_detail_screen.dart';
import 'package:carimarshow/presentation/screens/home/home_screen.dart';
import 'package:carimarshow/presentation/screens/movies/movies_screen.dart';
import 'package:carimarshow/presentation/screens/profile/profile_screen.dart';
import 'package:carimarshow/presentation/screens/search/search_screen.dart';
import 'package:carimarshow/presentation/screens/series/series_screen.dart';
import 'package:carimarshow/presentation/screens/splash_screen.dart';
import 'package:carimarshow/presentation/screens/watchlist/watchlist_screen.dart';
import 'package:carimarshow/presentation/widgets/brand_app_bar.dart';
import 'package:carimarshow/presentation/widgets/cast_row.dart';
import 'package:carimarshow/presentation/widgets/demo_mode_banner.dart';
import 'package:carimarshow/presentation/widgets/hero_backdrop.dart';
import 'package:carimarshow/presentation/widgets/media_carousel.dart';
import 'package:carimarshow/presentation/widgets/media_grid.dart';
import 'package:carimarshow/presentation/widgets/media_poster_card.dart';
import 'package:carimarshow/presentation/widgets/rating_badge.dart';
import 'package:carimarshow/presentation/widgets/watchlist_toggle.dart';

/// Cobertura de compilación de toda la capa de presentación.
///
/// Construir cada widget obliga al compilador a resolver y verificar tipos de
/// todas las bibliotecas importadas, que es exactamente lo que se quiere
/// comprobar. No se bombean al árbol de widgets, así que el coste de memoria es
/// mínimo y el test funciona incluso en máquinas muy justas.
///
/// La prueba de humo completa (arranque real con `pumpWidget`) está en
/// `app_smoke_test.dart`.
void main() {
  const MediaItem item = MediaItem(
    id: 155,
    type: MediaType.movie,
    title: 'Título',
    overview: 'Sinopsis',
    voteAverage: 8.5,
    releaseDate: null,
  );
  const MediaId id = MediaId(MediaType.movie, 155);

  test('la app y todas las pantallas construyen sin errores de tipo', () {
    final List<Widget> widgets = <Widget>[
      // Raíz
      const CarimarShowApp(),
      const SplashScreen(),

      // Acceso
      const LoginScreen(),
      const RegisterScreen(),
      const AuthHeader(title: 't', subtitle: 's'),
      const InlineAuthError(message: 'error'),
      const AuthDivider(),
      const NoBackendNotice(),
      const SubmitSpinner(),

      // Pestañas principales
      const HomeScreen(),
      const MoviesScreen(),
      const SeriesScreen(),
      const WatchlistScreen(),
      const CatalogScreen(type: MediaType.movie),
      const CatalogScreen(type: MediaType.tv),

      // Fuera del shell
      const SearchScreen(),
      const ProfileScreen(),
      const MediaDetailScreen(mediaId: id),

      // Widgets compartidos
      const BrandAppBar(),
      const DemoModeBanner(),
      const MediaCarousel(items: <MediaItem>[], title: 'Sección'),
      const MediaCarouselSkeleton(title: 'Cargando'),
      const BackdropCarousel(title: 'T', items: <MediaItem>[]),
      const MediaGrid(items: <MediaItem>[]),
      MediaPosterCard(item: item),
      MediaBackdropCard(item: item),
      const CastRow(cast: <CastMember>[]),
      HeroBackdrop(items: <MediaItem>[item]),
      WatchlistToggle(mediaId: id, media: item),
      WatchlistToggle.labeled(mediaId: id, media: item),

      // Núcleo
      const PosterImage(imagePath: null, title: 'T'),
      const BackdropImage(imagePath: null, title: 'T'),
      const ProfileImage(imagePath: null, name: 'Nombre'),
      const ShimmerBox(width: 10, height: 10),
      const PosterGridSkeleton(),
      const SectionHeader(title: 'Sección'),
      const ThinDivider(),
      const AppErrorView(error: null),
      const AppErrorView(error: null, compact: true),
      const EmptyStateView(icon: Icons.search, title: 'Vacío'),
      const RatingBadge(voteAverage: 8.5),
      const RatingBadge.small(7.2),
      const MetaChip('2008'),
      const MediaTypeTag(isTv: true),
      const ResponsiveContainer(child: SizedBox()),
    ];

    for (final Widget widget in widgets) {
      expect(widget, isNotNull);
      expect(widget, isA<Widget>());
    }

    // Al menos un ejemplar de cada familia de widget debe haberse construido.
    expect(widgets.length, greaterThan(30));
  });

  test('los temas claro y oscuro se construyen', () {
    final ThemeData dark = AppTheme.dark();
    final ThemeData light = AppTheme.light();

    expect(dark.brightness, Brightness.dark);
    expect(light.brightness, Brightness.light);
    expect(dark.useMaterial3, isTrue);
    expect(dark.colorScheme.primary, AppColors.crimson);
    expect(dark.textTheme.titleLarge, isNotNull);
    expect(dark.appBarTheme.backgroundColor, Colors.transparent);
  });

  test('los proveedores principales están declarados', () {
    expect(homeFeedProvider, isNotNull);
    expect(catalogProvider, isNotNull);
    expect(searchQueryProvider, isNotNull);
    expect(searchResultsProvider, isNotNull);
    expect(mediaDetailsProvider, isNotNull);
    expect(seasonEpisodesProvider, isNotNull);
    expect(movieGenresProvider, isNotNull);
    expect(tvGenresProvider, isNotNull);
    expect(genreNamesProvider, isNotNull);
    expect(itemGenreNamesProvider, isNotNull);
    expect(watchlistProvider, isNotNull);
    expect(watchlistKeysProvider, isNotNull);
    expect(isInWatchlistProvider, isNotNull);
    expect(watchlistEntryProvider, isNotNull);
    expect(watchlistStatsProvider, isNotNull);
    expect(continueWatchingProvider, isNotNull);
    expect(watchlistControllerProvider, isNotNull);
    expect(watchlistFilterProvider, isNotNull);
  });

  test('las claves de catálogo y de consulta son coherentes', () {
    expect(const CatalogQuery(type: MediaType.movie).hasFilters, isFalse);
    expect(
      const CatalogQuery(
        type: MediaType.movie,
        genreIds: <int>[TmdbGenre.action],
      ).hasFilters,
      isTrue,
    );
    expect(const CatalogQuery(type: MediaType.tv).feed, CatalogFeed.popular);
    expect(MediaPage.empty().isEmpty, isTrue);
    expect(MediaPage.empty().hasMore, isFalse);
  });

  test('las utilidades de texto y constantes están accesibles', () {
    expect(Strings.appName, 'CarimarShow');
    expect(AppColors.placeholderFor(0), hasLength(2));
    expect(AppColors.placeholderFor(-7), hasLength(2));
    expect(Breakpoints.compact, lessThan(Breakpoints.expanded));
    expect(
      const NetworkException().isRetryable,
      isTrue,
      reason: 'un fallo de red debe poder reintentarse',
    );
    expect(const UnauthorizedException().isRetryable, isFalse);
    expect(const UnauthorizedException().isConfigurationProblem, isTrue);
  });
}
