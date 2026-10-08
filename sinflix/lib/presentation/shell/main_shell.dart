import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';

/// Definición de las pestañas principales.
///
/// Se declara una sola vez y de aquí salen tanto la barra inferior (móvil) como
/// el rail lateral (tablet/escritorio), de modo que el orden y los iconos no
/// pueden desincronizarse.
enum MainTab {
  home(
    label: Strings.navHome,
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    path: '/home',
  ),
  movies(
    label: Strings.navMovies,
    icon: Icons.movie_outlined,
    selectedIcon: Icons.movie_rounded,
    path: '/movies',
  ),
  series(
    label: Strings.navSeries,
    icon: Icons.live_tv_outlined,
    selectedIcon: Icons.live_tv_rounded,
    path: '/series',
  ),
  watchlist(
    label: Strings.navWatchlist,
    icon: Icons.bookmarks_outlined,
    selectedIcon: Icons.bookmarks_rounded,
    path: '/watchlist',
  );

  const MainTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.path,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
}

/// Andamiaje de las cuatro pestañas principales.
///
/// Usa `StatefulShellRoute.indexedStack` de go_router: cada pestaña conserva su
/// propio historial y posición de desplazamiento, que es el comportamiento que
/// la gente espera de una app de este tipo (volver a Inicio no te tira al
/// principio de la lista).
///
/// En pantallas anchas la barra inferior se sustituye por un rail lateral, sin
/// duplicar ninguna pantalla.
class MainShell extends StatelessWidget {
  const MainShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  int get _currentIndex => navigationShell.currentIndex;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      // Un segundo toque en la pestaña activa vuelve al inicio de esa rama,
      // convención estándar en iOS y Android.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    // `navigationShell.currentIndex` conserva la última pestaña activa incluso
    // cuando se navega a rutas que viven fuera del shell (ficha, búsqueda,
    // perfil), así que no hace falta recalcular nada aquí.
    final String location = GoRouterState.of(context).uri.path;
    final int index = _currentIndex;

    final Widget body = ResponsiveContainer(child: navigationShell);

    if (context.usesNavigationRail) {
      return Scaffold(
        body: Row(
          children: <Widget>[
            _SideRail(
              selectedIndex: index,
              onDestinationSelected: _goBranch,
              location: location,
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: _goBranch,
        destinations: MainTab.values
            .map(
              (MainTab tab) => NavigationDestination(
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.selectedIcon),
                label: tab.label,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

/// Rail lateral para tablet y escritorio, con el logotipo arriba.
class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.location,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final String location;

  @override
  Widget build(BuildContext context) {
    final bool wide = context.screenWidth >= 1100;

    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      extended: wide,
      minExtendedWidth: 210,
      labelType: wide ? null : NavigationRailLabelType.all,
      leading: Padding(
        padding: EdgeInsets.only(top: 12, bottom: wide ? 20 : 8),
        child: _BrandMark(compact: !wide),
      ),
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  tooltip: Strings.searchHint,
                  onPressed: () => context.push('/search'),
                  isSelected: location.startsWith('/search'),
                  icon: const Icon(Icons.search_rounded),
                ),
                IconButton(
                  tooltip: Strings.navProfile,
                  onPressed: () => context.push('/profile'),
                  isSelected: location.startsWith('/profile'),
                  icon: const Icon(Icons.person_outline_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
      destinations: MainTab.values
          .map(
            (MainTab tab) => NavigationRailDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: Text(tab.label),
            ),
          )
          .toList(growable: false),
    );
  }
}

/// Logotipo de SinFlix.
class _BrandMark extends StatelessWidget {
  const _BrandMark({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.crimson,
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Text(
          'S',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.crimson,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'S',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            Strings.appName,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
