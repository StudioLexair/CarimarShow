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

/// Un test por ruta: si una revienta, falla UNA prueba con su nombre, no un
/// bloque entero, y el tiempo de reloj se mantiene acotado por ruta.
void main() {
  const List<String> rutas = <String>[
    '/home',
    '/movies',
    '/series',
    '/watchlist',
    '/search',
    '/profile',
    '/ajustes',
    '/negocio',
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
        authStateProvider.overrideWith(
          (Ref ref) => Stream<AppUser?>.value(
            const AppUser(
              id: 'rutas',
              email: 'rutas@carimarshow.test',
              displayName: 'Rutas',
            ),
          ),
        ),
      ],
      child: const CarimarShowApp(),
    );
  }

  for (final String ruta in rutas) {
    testWidgets('la ruta $ruta construye sin excepciones', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(await buildApp());
      await tester.pump();

      final GoRouter router = ProviderScope.containerOf(
        tester.element(find.byType(CarimarShowApp)),
      ).read(routerProvider);

      router.go(ruta);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        tester.takeException(),
        isNull,
        reason: 'la ruta $ruta lanzó una excepción',
      );
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        ruta,
        reason: 'el router no se quedó en $ruta',
      );
    });
  }
}
