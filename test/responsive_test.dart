import 'package:carimarshow/app.dart';
import 'package:carimarshow/data/repositories/local_auth_repository.dart';
import 'package:carimarshow/data/repositories/local_watchlist_repository.dart';
import 'package:carimarshow/domain/entities/app_user.dart';
import 'package:carimarshow/presentation/providers/auth_providers.dart';
import 'package:carimarshow/presentation/providers/core_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Auditoría de responsividad: la portada debe construir sin desbordes
/// (un overflow lanza excepción en tests) desde un móvil pequeño hasta un
/// escritorio ancho.
void main() {
  const List<(int, int, String)> tamanos = <(int, int, String)>[
    (320, 480, 'móvil muy pequeño'),
    (411, 915, 'móvil'),
    (768, 1024, 'tablet'),
    (1280, 800, 'escritorio'),
    (2560, 1440, 'escritorio ancho'),
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
              id: 'resp',
              email: 'resp@carimarshow.test',
              displayName: 'Resp',
            ),
          ),
        ),
      ],
      child: const CarimarShowApp(),
    );
  }

  for (final (int w, int h, String nombre) in tamanos) {
    testWidgets('portada sin desbordes en $nombre ($w×$h)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = Size(w.toDouble(), h.toDouble());
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(await buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        tester.takeException(),
        isNull,
        reason: 'desborde o excepción en $nombre (${w}x$h)',
      );
    });
  }
}
