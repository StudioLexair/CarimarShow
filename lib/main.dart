import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'app.dart';
import 'core/config/env.dart';
import 'data/repositories/local_auth_repository.dart';
import 'data/repositories/local_watchlist_repository.dart';
import 'presentation/providers/core_providers.dart';

/// Punto de entrada.
///
/// Aquí se inicializan los recursos asíncronos de arranque (preferencias y, si
/// procede, Supabase) y se inyectan en el [ProviderScope]. Hacerlo antes de
/// `runApp` evita que cualquier pantalla tenga que lidiar con un `Future`
/// pendiente y elimina los parpadeos de estado.
Future<void> main() async {
  // Necesario porque se llama a plugins antes de `runApp`.
  WidgetsFlutterBinding.ensureInitialized();

  _logStartup();

  // ── Preferencias locales ───────────────────────────────────────────────
  // Funcionan en las seis plataformas (en web usan localStorage).
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  // ── Backend (opcional) ─────────────────────────────────────────────────
  // Si falla la inicialización, la app NO debe morir: se degrada a modo local,
  // que es exactamente lo que haría si no hubiera credenciales.
  final sb.SupabaseClient? supabase = await _initSupabase();

  // ── Repositorios locales ───────────────────────────────────────────────
  // Se crean siempre: aunque haya Supabase, se usan para las preferencias de
  // dispositivo y como respaldo si la red falla.
  final LocalAuthRepository localAuth = LocalAuthRepository();
  await localAuth.initialize(preferences);

  final LocalWatchlistRepository localWatchlist = LocalWatchlistRepository();
  await localWatchlist.initialize(preferences);

  runApp(
    ProviderScope(
      // Riverpod 3 reintenta automáticamente los proveedores fallidos. Para una
      // app que consume una API con límite de peticiones eso es contraproducente:
      // convertiría un 429 en un bucle de llamadas. Se desactiva y el reintento
      // queda en manos del usuario, con el botón correspondiente.
      retry: (int retryCount, Object error) => null,
      observers: kDebugMode ? <ProviderObserver>[const _DebugObserver()] : null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        supabaseClientProvider.overrideWithValue(supabase),
        localAuthRepositoryProvider.overrideWithValue(localAuth),
        localWatchlistRepositoryProvider.overrideWithValue(localWatchlist),
      ],
      child: const CarimarShowApp(),
    ),
  );
}

/// Inicializa Supabase si hay credenciales. Nunca lanza.
Future<sb.SupabaseClient?> _initSupabase() async {
  if (!Env.isSupabaseConfigured) {
    _log('Supabase no configurado → cuentas y Mi lista en modo local.');
    return null;
  }
  try {
    await sb.Supabase.initialize(
      url: Env.supabaseUrl,
      // `publishableKey` sustituye al `anonKey` deprecado en supabase_flutter 2.x.
      publishableKey: Env.supabaseKey,
      debug: kDebugMode,
    );
    _log('Supabase inicializado: cuentas y sincronización activas.');
    return sb.Supabase.instance.client;
  } catch (error) {
    // Credenciales mal formadas, proyecto borrado, sin red en el arranque…
    // Se registra y se continúa en modo local en vez de bloquear la app.
    _log('No se pudo iniciar Supabase ($error) → modo local.');
    return null;
  }
}

void _logStartup() {
  if (!kDebugMode) return;
  _log('Arrancando CarimarShow en modo ${Env.environment.name}');
  Env.debugSummary.forEach(
    (String key, Object value) => _log('  $key: $value'),
  );
  if (Env.isDemoMode) {
    _log(
      '  → Se usará el catálogo de demostración (assets/data/demo_catalog.json)',
    );
  }
}

void _log(String message) {
  if (kDebugMode) debugPrint('[CarimarShow] $message');
}

/// Observador que registra el ciclo de vida de los proveedores en desarrollo.
///
/// Usa la firma de Riverpod 3 (`ProviderObserverContext`), que unifica los
/// parámetros que antes iban sueltos. Se declara `final` porque
/// `ProviderObserver` es una clase `base` y exige ese modificador en las
/// subclases.
final class _DebugObserver extends ProviderObserver {
  const _DebugObserver();

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    if (newValue is AsyncError) {
      _log('✕ ${context.provider.runtimeType} → ${newValue.error}');
    }
  }

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    _log('✕ fallo en ${context.provider.runtimeType}: $error');
  }
}
