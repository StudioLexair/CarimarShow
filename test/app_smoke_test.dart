import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carimarshow/app.dart';
import 'package:carimarshow/data/repositories/local_auth_repository.dart';
import 'package:carimarshow/data/repositories/local_watchlist_repository.dart';
import 'package:carimarshow/data/mappers/media_mapper.dart';
import 'package:carimarshow/domain/entities/media_item.dart';
import 'package:carimarshow/domain/entities/media_type.dart';
import 'package:carimarshow/presentation/providers/core_providers.dart';

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
      child: const CarimarShowApp(),
    );
  }

  /// Bombea hasta que [finder] encuentra algo, o hasta agotar los intentos.
  ///
  /// Antes este test usaba duraciones fijas (`pump(100ms)`, `pump(400ms)`).
  /// Eso lo hacía frágil entre versiones de Flutter: la redirección del
  /// router puede resolverse un frame más tarde de una versión a otra y el
  /// test fallaba sin que hubiera ningún bug real.
  ///
  /// Cada intento combina dos relojes a propósito:
  ///   · `runAsync` deja pasar async REAL: el primer evento de un stream
  ///     `async*` (la sesión restaurada) se entrega fuera del reloj ficticio
  ///     de `testWidgets`, y sin esto el splash no se va nunca.
  ///   · `pump` avanza el reloj ficticio para que el router y los builders
  ///     reconstruyan con el estado nuevo.
  ///
  /// No se usa `pumpAndSettle` porque la portada tiene animaciones continuas
  /// (avance automático del héroe) y no asentaría nunca.
  Future<void> settleUntil(
    WidgetTester tester,
    Finder finder, {
    int intentos = 40,
  }) async {
    for (int i = 0; i < intentos; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Lleva la app desde el arranque hasta la pantalla de acceso.
  Future<void> hastaLogin(WidgetTester tester) async {
    await tester.pumpWidget(await buildApp());
    // Primer frame: la sesión aún se está resolviendo, así que toca el splash.
    await tester.pump();
    await settleUntil(tester, find.text('Iniciar sesión'));
  }

  testWidgets('sin sesión, el router muestra la pantalla de acceso', (
    WidgetTester tester,
  ) async {
    await hastaLogin(tester);

    // Sin Supabase no se ofrece registro, solo la sesión local.
    expect(find.text('Crear cuenta'), findsNothing);
    expect(find.text('Entrar como invitado'), findsOneWidget);
  });

  testWidgets('la sesión local lleva a la portada con el catálogo de demo', (
    WidgetTester tester,
  ) async {
    await hastaLogin(tester);

    await tester.tap(find.text('Entrar como invitado'));
    // El modo invitado pide confirmación explicando que los datos quedan
    // solo en el dispositivo: se confirma el diálogo antes de seguir.
    await settleUntil(tester, find.byType(AlertDialog));
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Entrar como invitado'),
      ),
    );
    await settleUntil(tester, find.text('Mi lista'));
    // El aviso de modo demo y el catálogo se resuelven con I/O real
    // (lectura del asset), así que se esperan con settleUntil, que alterna
    // async real y reloj ficticio, en vez de pumps a pelo.
    await settleUntil(tester, find.textContaining('Modo demo'));

    // La navegación inferior del shell está presente.
    expect(find.text('Inicio'), findsWidgets);
    expect(find.text('Películas'), findsWidgets);
    expect(find.text('Series'), findsWidgets);
    expect(find.text('Mi lista'), findsWidgets);

    // Y el aviso de modo demo, que es lo esperado sin token de TMDB.
    expect(find.textContaining('Modo demo'), findsWidgets);
  });

  // Antes este test buscaba los títulos ficticios en la pantalla, pero en la
  // superficie de 800x600 de `testWidgets` los carruseles de la portada quedan
  // por debajo del pliegue y sus tarjetas ni se construyen; y cargar el asset
  // con `rootBundle` dentro de un test plano llegaba a colgar el binario.
  // Lo que de verdad se quiere garantizar aquí es que el asset existe, se
  // parsea y se mapea a entidades coherentes: se comprueba leyendo el fichero
  // y pasando el JSON por el mismo mapeador que usa la app, sin binding ni
  // providers de por medio. Determinista y rápido.
  test('el catálogo de demo se parsea y se mapea desde los assets', () {
    const Map<MediaType, String> claves = <MediaType, String>{
      MediaType.movie: 'movies',
      MediaType.tv: 'series',
    };
    const List<String> titulosDemo = <String>[
      'Órbita roja',
      'El último faro',
      'Ceniza de neón',
      'Estación Polar',
      'Mareas',
    ];

    final File asset = File('assets/data/demo_catalog.json');
    expect(
      asset.existsSync(),
      isTrue,
      reason: 'el asset debe existir y estar declarado en pubspec',
    );

    final Map<String, dynamic> data =
        jsonDecode(asset.readAsStringSync()) as Map<String, dynamic>;

    for (final MapEntry<MediaType, String> e in claves.entries) {
      final List<Map<String, dynamic>> raw = List<Map<String, dynamic>>.from(
        (data[e.value] as List).cast<Map<String, dynamic>>(),
      );
      expect(raw, isNotEmpty, reason: 'el bloque ${e.value} vino vacío');

      final List<MediaItem> items = MediaMapper.items(raw, fallbackType: e.key);
      expect(items, isNotEmpty, reason: 'el mapeador descartó todo ${e.value}');

      for (final MediaItem item in items) {
        expect(item.id, greaterThan(0), reason: 'ítem de ${e.value} sin id');
        expect(item.type, e.key, reason: 'ítem de ${e.value} con tipo erróneo');
      }
      expect(
        items.any((MediaItem i) => titulosDemo.contains(i.title)),
        isTrue,
        reason: 'ningún título ficticio conocido apareció en ${e.value}',
      );
    }
  });
}
