import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sinflix/app.dart';
import 'package:sinflix/data/repositories/local_auth_repository.dart';
import 'package:sinflix/data/repositories/local_watchlist_repository.dart';
import 'package:sinflix/presentation/providers/core_providers.dart';

/// Prueba de humo de extremo a extremo.
///
/// Arranca la app real —router, tema, shell y todas las pantallas— sin ninguna
/// credencial, que es exactamente el escenario de un clon recién descargado.
/// Verifica que:
///   1. No hay sesión → el router redirige al acceso.
///   2. La sesión local funciona y lleva a la portada.
///   3. El catálogo de demo se carga desde los assets empaquetados.
///
/// De paso fuerza la compilación de todo el árbol de widgets: si cualquier
/// pantalla deja de compilar, este test falla.
///
/// ⚠️ **Requisitos:** bombea la aplicación completa, así que necesita unos
/// 2 GB de RAM libres. En máquinas o CI muy justos de memoria el proceso
/// `flutter_tester` puede abortar por falta de memoria (no por un fallo del
/// código). En ese caso ejecuta el resto de la suite, que incluye la cobertura
/// de compilación de todas las pantallas sin coste de memoria:
///
///     flutter test test/core test/domain test/data test/compile_coverage_test.dart
void main() {
  /// Construye el `ProviderScope` con las mismas dependencias que `main()`,
  /// pero con almacenamiento en memoria.
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
      ],
      child: const SinFlixApp(),
    );
  }

  testWidgets('sin sesión, el router muestra la pantalla de acceso', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await buildApp());

    // Primer frame: la sesión aún se está resolviendo, así que toca el splash.
    await tester.pump();
    // El stream de autenticación emite `null` y el router redirige a /login.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Iniciar sesión'), findsWidgets);
    expect(find.text('Contraseña'), findsOneWidget);

    // Sin Supabase no se ofrece registro, solo la sesión local.
    expect(find.text('Crear cuenta'), findsNothing);
    expect(find.text('Continuar (modo local)'), findsOneWidget);
  });

  testWidgets('la sesión local lleva a la portada con el catálogo de demo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Continuar (modo local)'));

    // Se bombea con duraciones explícitas en vez de `pumpAndSettle`: la
    // portada tiene animaciones continuas (avance automático del héroe) y
    // `pumpAndSettle` no terminaría nunca.
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    // La navegación inferior del shell está presente.
    expect(find.text('Inicio'), findsWidgets);
    expect(find.text('Películas'), findsWidgets);
    expect(find.text('Series'), findsWidgets);
    expect(find.text('Mi lista'), findsWidgets);

    // Y el aviso de modo demo, que es lo esperado sin token de TMDB.
    expect(find.textContaining('Modo demo'), findsWidgets);
  });

  testWidgets('el catálogo de demo carga títulos desde los assets', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Continuar (modo local)'));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    // Al menos uno de los títulos ficticios incluidos en demo_catalog.json
    // debe haber llegado a la pantalla: prueba de que el asset existe, se
    // parsea y se mapea a entidades sin errores.
    final bool apareceDemo = <String>[
      'Órbita roja',
      'El último faro',
      'Ceniza de neón',
      'Estación Polar',
      'Mareas',
    ].any((String titulo) => find.textContaining(titulo).evaluate().isNotEmpty);

    expect(
      apareceDemo,
      isTrue,
      reason: 'ningún título del catálogo de demo llegó a la UI',
    );
  });
}
