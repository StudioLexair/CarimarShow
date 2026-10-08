/// Acceso centralizado a la configuración de la aplicación.
///
/// Los valores se inyectan en tiempo de compilación con `--dart-define`, que
/// es la forma recomendada de pasar secretos a Flutter: quedan embebidos en el
/// binario y nunca en un asset que se pueda leer con un editor de texto.
///
/// ```bash
/// flutter run \
///   --dart-define=TMDB_READ_TOKEN=eyJhbGci... \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
/// ```
///
/// O simplemente `./scripts/run.sh`, que lee el archivo `.env`.
///
/// Todos los valores son opcionales: si faltan, la app entra en **modo demo**
/// con un catálogo local y sin cuentas de usuario. Nunca se rompe al arrancar.
library;

/// Entorno de ejecución de la aplicación.
enum AppEnvironment {
  development,
  staging,
  production;

  static AppEnvironment parse(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'prod':
      case 'production':
        return AppEnvironment.production;
      case 'staging':
      case 'stage':
        return AppEnvironment.staging;
      default:
        return AppEnvironment.development;
    }
  }

  bool get isProduction => this == AppEnvironment.production;
  bool get isDevelopment => this == AppEnvironment.development;
}

/// Variables de entorno leídas de `--dart-define`.
abstract final class Env {
  // ── TMDB ─────────────────────────────────────────────────────────────
  /// Token de lectura v4 de TMDB (`API Read Access Token`).
  static const String tmdbReadToken = String.fromEnvironment('TMDB_READ_TOKEN');

  /// Clave API v3 de TMDB. Alternativa al token de lectura.
  static const String tmdbApiKey = String.fromEnvironment('TMDB_API_KEY');

  /// Idioma del contenido: `es-ES`, `es-MX`, `en-US`...
  static const String tmdbLanguage = String.fromEnvironment(
    'TMDB_LANGUAGE',
    defaultValue: 'es-ES',
  );

  /// Región ISO-3166-1 para fechas de estreno y disponibilidad.
  static const String tmdbRegion = String.fromEnvironment(
    'TMDB_REGION',
    defaultValue: 'ES',
  );

  // ── Supabase ─────────────────────────────────────────────────────────
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Clave pública del proyecto.
  ///
  /// En supabase_flutter 2.x el parámetro se llama `publishableKey`; se acepta
  /// `SUPABASE_ANON_KEY` como alias heredado para no romper proyectos que ya
  /// estuvieran configurados.
  static const String _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const String _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Clave efectiva para `Supabase.initialize(publishableKey: ...)`.
  ///
  /// Nunca debe ser la *secret key*: esta clave viaja empaquetada dentro de la
  /// app y por tanto es pública por diseño. Lo que protege los datos de cada
  /// usuario son las políticas RLS de la base de datos, no el secreto de la
  /// clave.
  static String get supabaseKey =>
      _publishableKey.isNotEmpty ? _publishableKey : _anonKey;

  // ── App ──────────────────────────────────────────────────────────────
  static const String _rawEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static AppEnvironment get environment => AppEnvironment.parse(_rawEnv);

  // ── Capacidad detectada ──────────────────────────────────────────────
  /// ¿Hay credenciales para consultar el catálogo real de TMDB?
  static bool get isTmdbConfigured =>
      tmdbReadToken.isNotEmpty || tmdbApiKey.isNotEmpty;

  /// ¿Hay un backend Supabase configurado para cuentas y lista sincronizada?
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// La app arranca en modo demo (sin red, sin cuentas) si no hay TMDB.
  static bool get isDemoMode => !isTmdbConfigured;

  /// Resumen seguro para logs. Nunca incluye el valor de los secretos.
  static Map<String, Object> get debugSummary => <String, Object>{
    'APP_ENV': environment.name,
    'TMDB': isTmdbConfigured ? 'configurado' : 'ausente (modo demo)',
    'TMDB_LANGUAGE': tmdbLanguage,
    'TMDB_REGION': tmdbRegion,
    'Supabase': isSupabaseConfigured ? 'configurado' : 'ausente (local)',
  };
}
