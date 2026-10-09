import 'package:carimarshow/app.dart';
import 'package:carimarshow/data/repositories/local_auth_repository.dart';
import 'package:carimarshow/data/repositories/local_watchlist_repository.dart';
import 'package:carimarshow/domain/entities/app_user.dart';
import 'package:carimarshow/presentation/providers/auth_providers.dart';
import 'package:carimarshow/presentation/providers/core_providers.dart';
import 'package:carimarshow/presentation/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Recorre todas las rutas de la aplicación y comprueba que ninguna revienta.
///
/// No valida el contenido de cada pantalla (eso lo cubren el smoke test y la
/// cobertura de compilación): valida que el router responde a cada dirección
/// y que el árbol se construye sin excepciones, que es lo que se rompe cuando
/// alguien renombra una ruta o olvida un import.
void main() {
  const List<String> rutas = <String>[
    '/home',
    '/movies',
    '/series',
    '/watchlist',
    '/search',
    '/profile',
    '/negocio',
    '/title/movie/155',
  ];

  Future<Widget> buildApp() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final LocalAuthRepository auth = LocalAuthRepository();
    await auth.initialize(prefs);
    final LocalWatchlistRepository watchlist = LocalWatchlistRepository();
    await watchlist.initialize(prefs);

    return ProviderScope(
      retry: (int retryCount, Object error) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseClientProvider.overrideWithValue(null),
        localAuthRepositoryProvider.overrideWithValue(auth),
        localWatchlistRepositoryProvider.overrideWithValue(watchlist),
        // Sesión resuelta de inmediato para poder entrar en rutas privadas.
        authStateProvider.overrideWith(
          (Ref ref) => Stream<AppUser?>.value(
            const AppUser(
              id: 'ruta-test',
              email: 'rutas@carimarshow.test',
              displayName: 'Rutas',
            ),
          ),
        ),
      ],
      child: const CarimarShowApp(),
    );
  }

  testWidgets('todas las rutas construyen sin excepciones', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await buildApp());
    await tester.pump();

    final GoRouter router = ProviderScope.containerOf(
      tester.element(find.byType(CarimarShowApp)),
    ).read(routerProvider);

    for (final String ruta in rutas) {
      router.go(ruta);
      // Reloj ficticio más un poco de async real para que asienten los
      // redirects y las cargas diferidas de cada pantalla.
      for (int i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 120));
      }

      expect(
        tester.takeException(),
        isNull,
        reason: 'la ruta $ruta lanzó una excepción al construir',
      );

      final String ubicacion =
          router.routerDelegate.currentConfiguration.last.matchedLocation;
      expect(
        ubicacion,
        ruta.startsWith('/title') ? startsWith('/title') : ruta,
        reason: 'el router no se quedó en $ruta',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
