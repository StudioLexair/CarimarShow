import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/cache/catalog_cache.dart';
import '../../core/utils/query_corrector.dart';
import '../../core/config/app_config.dart';
import '../../data/repositories/local_auth_repository.dart';
import '../../data/repositories/local_watchlist_repository.dart';
import '../../data/repositories/supabase_auth_repository.dart';
import '../../data/repositories/supabase_watchlist_repository.dart';
import '../../data/sources/demo_media_source.dart';
import '../../data/sources/tmdb_media_source.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/media_repository.dart';
import '../../domain/repositories/watchlist_repository.dart';

// ══════════════════════════════════════════════════════════════════════════
//  Infraestructura
// ══════════════════════════════════════════════════════════════════════════
//
//  Estos proveedores se declaran sin implementación y se sobrescriben en
//  `main.dart` con las instancias ya inicializadas. Es el patrón habitual para
//  recursos asíncronos de arranque: evita que cada consumidor tenga que
//  manejar `Future` y garantiza una única instancia en toda la app.
// ══════════════════════════════════════════════════════════════════════════

final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>(
      (Ref ref) => throw UnimplementedError(
        'sharedPreferencesProvider debe sobrescribirse en main()',
      ),
    );

/// Cliente de Supabase, o `null` si no se ha configurado backend.
///
/// Toda la app consulta este valor para decidir entre cuentas reales y modo
/// local. `null` no es un error: es un modo de ejecución soportado.
final Provider<sb.SupabaseClient?> supabaseClientProvider =
    Provider<sb.SupabaseClient?>((Ref ref) => null);

final Provider<LocalAuthRepository> localAuthRepositoryProvider =
    Provider<LocalAuthRepository>(
      (Ref ref) => throw UnimplementedError(
        'localAuthRepositoryProvider debe sobrescribirse en main()',
      ),
    );

final Provider<LocalWatchlistRepository> localWatchlistRepositoryProvider =
    Provider<LocalWatchlistRepository>(
      (Ref ref) => throw UnimplementedError(
        'localWatchlistRepositoryProvider debe sobrescribirse en main()',
      ),
    );

// ══════════════════════════════════════════════════════════════════════════
//  Configuración
// ══════════════════════════════════════════════════════════════════════════

final Provider<AppConfig> appConfigProvider = Provider<AppConfig>(
  (Ref ref) => AppConfig.fromEnv(),
);

/// `true` cuando la app está sirviendo el catálogo ficticio de respaldo.
///
/// La UI lo usa para mostrar un aviso discreto, de forma que nadie confunda el
/// contenido de demo con el catálogo real por un problema de configuración.
final Provider<bool> demoModeProvider = Provider<bool>(
  (Ref ref) => ref.watch(appConfigProvider).useDemoCatalog,
);

// ══════════════════════════════════════════════════════════════════════════
//  Repositorios
// ══════════════════════════════════════════════════════════════════════════

/// Catálogo: TMDB en directo si hay credenciales, demo local si no.
/// Caché en disco de respuestas del catálogo (offline + botón «liberar espacio»).
final Provider<CatalogCache> catalogCacheProvider = Provider<CatalogCache>((
  Ref ref,
) {
  final SharedPreferences prefs = ref.watch(sharedPreferencesProvider);
  // El léxico del corrector vive en las mismas preferencias.
  LexiconStore.instance.bind(prefs);
  return CatalogCache(prefs);
});

final Provider<MediaRepository> mediaRepositoryProvider =
    Provider<MediaRepository>((Ref ref) {
      final AppConfig config = ref.watch(appConfigProvider);
      final MediaRepository repository = config.useDemoCatalog
          ? DemoMediaSource()
          : TmdbMediaSource(
              config: config,
              cache: ref.watch(catalogCacheProvider),
            );
      ref.onDispose(repository.dispose);
      return repository;
    });

/// Autenticación: Supabase si hay backend; si no, sesión local de invitado.
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) {
      final sb.SupabaseClient? client = ref.watch(supabaseClientProvider);
      final AuthRepository repository = client == null
          ? ref.watch(localAuthRepositoryProvider)
          : SupabaseAuthRepository(client: client);
      // La instancia local se gestiona en main(); solo se libera la remota.
      if (client != null) ref.onDispose(repository.dispose);
      return repository;
    });

/// «Mi lista»: sincronizada con Supabase o persistida en el dispositivo.
final Provider<WatchlistRepository> watchlistRepositoryProvider =
    Provider<WatchlistRepository>((Ref ref) {
      final sb.SupabaseClient? client = ref.watch(supabaseClientProvider);
      final WatchlistRepository repository = client == null
          ? ref.watch(localWatchlistRepositoryProvider)
          : SupabaseWatchlistRepository(client: client);
      if (client != null) ref.onDispose(repository.dispose);
      return repository;
    });

// ══════════════════════════════════════════════════════════════════════════
//  Preferencias de la app
// ══════════════════════════════════════════════════════════════════════════

const String _kThemeMode = 'carimarshow.prefs.themeMode';
const String _kAdultContent = 'carimarshow.prefs.adultContent';

/// Descodifica el valor guardado, tolerando datos inválidos o de versiones
/// anteriores de la app.
ThemeMode decodeThemeMode(String? raw) => switch (raw) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

String encodeThemeMode(ThemeMode mode) => mode.name;

/// Modo de tema elegido por el usuario, persistido entre sesiones.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final SharedPreferences prefs = ref.read(sharedPreferencesProvider);
    return decodeThemeMode(prefs.getString(_kThemeMode));
  }

  Future<void> set(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kThemeMode, encodeThemeMode(mode));
  }

  /// Alterna entre claro y oscuro, ignorando la preferencia del sistema.
  Future<void> toggle() =>
      set(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}

final NotifierProvider<ThemeModeNotifier, ThemeMode> themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Mostrar contenido para adultos en los listados.
class AdultContentNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(_kAdultContent) ?? false;

  Future<void> set(bool value) async {
    if (state == value) return;
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_kAdultContent, value);
  }
}

final NotifierProvider<AdultContentNotifier, bool> adultContentProvider =
    NotifierProvider<AdultContentNotifier, bool>(AdultContentNotifier.new);
