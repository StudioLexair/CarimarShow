import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/media_id.dart';
import '../../domain/entities/media_type.dart';
import '../providers/auth_providers.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/detail/media_detail_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/movies/movies_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/series/series_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/watchlist/watchlist_screen.dart';
import '../shell/main_shell.dart';

/// Rutas que no requieren sesión iniciada.
const Set<String> _publicPaths = <String>{'/splash', '/login', '/register'};

/// Enrutador de la aplicación.
///
/// La lógica de acceso vive aquí y en un solo sitio: cada navegación pasa por
/// [redirect], que decide entre splash (sesión aún sin resolver), login (sin
/// sesión) y la ruta pedida. Ninguna pantalla tiene que comprobar la sesión por
/// su cuenta, que es donde suelen aparecer los parpadeos y los bucles.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  // `refreshListenable` necesita un Listenable; se puentea el stream de
  // autenticación con un ValueNotifier para reevaluar `redirect` en cada cambio.
  final ValueNotifier<int> refresh = ValueNotifier<int>(0);

  final ProviderSubscription<AsyncValue<AppUser?>> subscription = ref
      .listen<AsyncValue<AppUser?>>(authStateProvider, (
        AsyncValue<AppUser?>? previous,
        AsyncValue<AppUser?> next,
      ) {
        refresh.value++;
      }, fireImmediately: true);

  ref.onDispose(() {
    subscription.close();
    refresh.dispose();
  });

  return GoRouter(
    initialLocation: '/home',
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final AsyncValue<AppUser?> auth = ref.read(authStateProvider);
      final String location = state.matchedLocation;

      // 1. Todavía no se sabe si hay sesión → splash, nunca login.
      //    Si se mandara al usuario a login durante la resolución inicial, se
      //    vería un parpadeo de la pantalla de acceso en cada arranque en frío.
      if (auth.isLoading) {
        return location == '/splash' ? null : '/splash';
      }

      final bool signedIn = auth.value != null;
      final bool isPublic = _publicPaths.contains(location);

      // 2. Sin sesión y la ruta es privada → login.
      if (!signedIn && !isPublic) return '/login';

      // 3. Con sesión, se sale del splash y del acceso.
      if (signedIn && isPublic) return '/home';

      // 4. Error de sesión (token caducado irrecuperable) → login.
      if (auth.hasError && !isPublic) return '/login';

      return null;
    },
    routes: <RouteBase>[
      // ── Fuera del shell ────────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (BuildContext context, GoRouterState state) =>
            const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (BuildContext context, GoRouterState state) =>
            const RegisterScreen(),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (BuildContext context, GoRouterState state) =>
            const SearchScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (BuildContext context, GoRouterState state) =>
            const ProfileScreen(),
      ),
      GoRoute(
        path: '/title/:type/:id',
        name: 'title',
        builder: (BuildContext context, GoRouterState state) {
          final MediaId? id = _parseMediaId(state);
          if (id == null) return const _InvalidTitleScreen();
          return MediaDetailScreen(mediaId: id);
        },
      ),

      // ── Pestañas principales ───────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell shell,
            ) => MainShell(navigationShell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (BuildContext context, GoRouterState state) =>
                    const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/movies',
                name: 'movies',
                builder: (BuildContext context, GoRouterState state) =>
                    const MoviesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/series',
                name: 'series',
                builder: (BuildContext context, GoRouterState state) =>
                    const SeriesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/watchlist',
                name: 'watchlist',
                builder: (BuildContext context, GoRouterState state) =>
                    const WatchlistScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) =>
        _RouteNotFoundScreen(location: state.uri.toString()),
  );
});

/// Extrae `MediaId` de los parámetros de la ruta `/title/:type/:id`.
///
/// Devuelve `null` si el tipo no existe o el id no es numérico, en cuyo caso se
/// muestra una pantalla de error en vez de reventar con una excepción.
MediaId? _parseMediaId(GoRouterState state) {
  final String? rawType = state.pathParameters['type'];
  final String? rawId = state.pathParameters['id'];
  if (rawType == null || rawId == null) return null;

  final MediaType? type = MediaType.tryParse(rawType);
  final int? id = int.tryParse(rawId);
  if (type == null || id == null) return null;

  return MediaId(type, id);
}

class _InvalidTitleScreen extends StatelessWidget {
  const _InvalidTitleScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Título no válido')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.link_off_rounded, size: 40),
              const SizedBox(height: 16),
              const Text(
                'El enlace no apunta a ningún título reconocible.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/home'),
                child: const Text('Volver a Inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteNotFoundScreen extends StatelessWidget {
  const _RouteNotFoundScreen({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Página no encontrada')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.explore_off_rounded, size: 44),
              const SizedBox(height: 16),
              Text(
                'No existe ninguna ruta para:\n$location',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/home'),
                child: const Text('Ir a Inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
