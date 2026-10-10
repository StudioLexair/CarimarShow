/// Textos de la interfaz centralizados.
///
/// No es un sistema de internacionalización completo, pero evita cadenas
/// sueltas por toda la UI y deja el camino preparado para migrar a ARB
/// (`flutter gen-l10n`) cuando se necesiten varios idiomas.
abstract final class Strings {
  static const String appName = 'CarimarShow';
  static const String appTagline =
      'Películas y series, en todos tus dispositivos';

  // ── Navegación ───────────────────────────────────────────────────────
  static const String navHome = 'Inicio';
  static const String navMovies = 'Películas';
  static const String navSeries = 'Series';
  static const String navWatchlist = 'Mi lista';
  static const String navProfile = 'Perfil';

  // ── Autenticación ────────────────────────────────────────────────────
  static const String login = 'Iniciar sesión';
  static const String register = 'Crear cuenta';
  static const String logout = 'Cerrar sesión';
  static const String email = 'Correo electrónico';
  static const String password = 'Contraseña';
  static const String displayName = 'Nombre de usuario';
  static const String continueAsGuest = 'Continuar sin cuenta';
  static const String noAccount = '¿No tienes cuenta?';
  static const String hasAccount = '¿Ya tienes cuenta?';
  static const String forgotPassword = '¿Olvidaste tu contraseña?';

  // ── Catálogo ─────────────────────────────────────────────────────────
  static const String trending = 'Tendencias de la semana';
  static const String popularMovies = 'Películas populares';
  static const String topRatedMovies = 'Mejor valoradas';
  static const String upcoming = 'Próximos estrenos';
  static const String nowPlaying = 'En cines';
  static const String popularSeries = 'Series populares';
  static const String topRatedSeries = 'Series mejor valoradas';
  static const String onTheAir = 'En emisión';
  static const String airingToday = 'Se emiten hoy';
  static const String similar = 'Títulos similares';
  static const String recommendations = 'Recomendaciones';
  static const String cast = 'Reparto principal';
  static const String seasons = 'Temporadas';
  static const String episodes = 'episodios';
  static const String watchTrailer = 'Ver tráiler';
  static const String noTrailer = 'Sin tráiler disponible';

  // ── Búsqueda ─────────────────────────────────────────────────────────
  static const String searchHint = 'Busca películas, series, personas…';
  static const String searchEmpty = 'Escribe algo para empezar a buscar';
  static const String searchNoResults = 'Sin resultados para';

  // ── Mi lista ─────────────────────────────────────────────────────────
  static const String watchlistEmpty = 'Tu lista está vacía';
  static const String watchlistEmptyHint =
      'Añade películas y series con el botón + para tenerlas siempre a mano.';
  static const String addedToWatchlist = 'Añadido a Mi lista';
  static const String removedFromWatchlist = 'Quitado de Mi lista';

  // ── Estados ──────────────────────────────────────────────────────────
  static const String loading = 'Cargando…';
  static const String retry = 'Reintentar';
  static const String somethingWentWrong = 'Algo ha salido mal';
  static const String noConnection = 'Sin conexión';
  static const String noConnectionHint =
      'Revisa tu conexión a internet y vuelve a intentarlo.';
  static const String demoModeBanner =
      'Modo demo: catálogo local. Configura TMDB_READ_TOKEN para ver contenido real.';

  // ── Errores legibles ─────────────────────────────────────────────────
  static const String errorUnauthorized =
      'Credenciales de TMDB incorrectas o revocadas.';
  static const String errorNotFound = 'No encontramos ese título.';
  static const String errorRateLimit =
      'Demasiadas peticiones seguidas. Espera unos segundos.';
  static const String errorServer =
      'El servidor no responde. Inténtalo más tarde.';
  static const String errorNetwork =
      'No se pudo conectar. Comprueba tu conexión a internet.';
  static const String errorUnknown = 'Error inesperado.';

  // ── Validación ───────────────────────────────────────────────────────
  static const String fieldRequired = 'Este campo es obligatorio';
  static const String invalidEmail = 'Introduce un correo válido';
  static const String passwordTooShort = 'Mínimo 8 caracteres';
  static const String passwordNeedsNumber = 'Debe incluir al menos un número';

  // ── Atribución ───────────────────────────────────────────────────────
  static const String tmdbAttribution =
      'Este producto usa la API de TMDB pero no está avalado ni certificado por TMDB.';
}

/// Versión mostrada en «Acerca de». Se sube con cada release.
const String kAppVersion = '1.0.4';
