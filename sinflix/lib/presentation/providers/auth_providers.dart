import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'core_providers.dart';

// ══════════════════════════════════════════════════════════════════════════
//  Sesión
// ══════════════════════════════════════════════════════════════════════════

/// Flujo del usuario actual. Emite `null` cuando no hay sesión.
///
/// Es la única fuente de verdad: el router la observa para redirigir a la
/// pantalla de acceso, y las pantallas la leen para mostrar el perfil.
final StreamProvider<AppUser?> authStateProvider = StreamProvider<AppUser?>(
  (Ref ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// Usuario actual de forma síncrona (`null` mientras se resuelve la sesión).
final Provider<AppUser?> currentUserProvider = Provider<AppUser?>(
  (Ref ref) => ref.watch(authStateProvider).value,
);

/// `true` solo cuando la sesión ya está resuelta **y** existe usuario.
///
/// Se distingue a propósito de «todavía cargando»: durante la resolución inicial
/// la app muestra el splash, no la pantalla de login.
final Provider<bool> isAuthenticatedProvider = Provider<bool>((Ref ref) {
  final AsyncValue<AppUser?> auth = ref.watch(authStateProvider);
  return auth.value != null;
});

/// `true` mientras no se ha resuelto el primer evento de sesión.
final Provider<bool> isResolvingSessionProvider = Provider<bool>(
  (Ref ref) => ref.watch(authStateProvider).isLoading,
);

/// Identificador estable para almacenar datos por usuario.
///
/// Sin sesión se usa `'anonymous'`, de modo que «Mi lista» siga funcionando
/// antes de iniciar sesión y no se mezcle después con la de una cuenta real.
final Provider<String> currentUserIdProvider = Provider<String>(
  (Ref ref) => ref.watch(currentUserProvider)?.id ?? 'anonymous',
);

/// `true` si la app tiene cuentas reales (backend configurado).
///
/// La pantalla de acceso lo usa para ocultar el registro y ofrecer solo el modo
/// invitado cuando no hay Supabase.
final Provider<bool> accountsEnabledProvider = Provider<bool>(
  (Ref ref) => ref.watch(authRepositoryProvider).isRemoteEnabled,
);

// ══════════════════════════════════════════════════════════════════════════
//  Controlador de autenticación
// ══════════════════════════════════════════════════════════════════════════

/// Estado del formulario de acceso, para mostrar spinner y errores en línea.
class AuthState extends Equatable {
  const AuthState.idle() : isSubmitting = false, error = null;

  const AuthState.submitting() : isSubmitting = true, error = null;

  const AuthState.failed(this.error) : isSubmitting = false;

  final bool isSubmitting;

  /// Mensaje ya traducido y apto para mostrar al usuario.
  final String? error;

  bool get hasError => error != null;

  @override
  List<Object?> get props => <Object?>[isSubmitting, error];
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState.idle();

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> signIn({required String email, required String password}) =>
      _run(() => _repo.signIn(email: email, password: password));

  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) => _run(
    () => _repo.signUp(
      email: email,
      password: password,
      displayName: displayName,
    ),
  );

  /// Sesión local sin servidor. Nunca falla: siempre devuelve `true`.
  Future<bool> continueAsGuest({String? displayName}) =>
      _run(() => _repo.signInAsGuest(displayName: displayName));

  Future<bool> sendPasswordReset(String email) async {
    state = const AuthState.submitting();
    final AuthResult result = await _repo.sendPasswordReset(email);
    switch (result) {
      case AuthSuccess():
        state = const AuthState.idle();
        return true;
      case AuthFailure(:final message):
        state = AuthState.failed(message);
        return false;
    }
  }

  Future<void> signOut() async {
    state = const AuthState.submitting();
    try {
      await _repo.signOut();
      state = const AuthState.idle();
    } catch (error) {
      state = AuthState.failed('No se pudo cerrar la sesión: $error');
    }
  }

  Future<void> updateProfile({String? displayName, String? avatarUrl}) =>
      _repo.updateProfile(displayName: displayName, avatarUrl: avatarUrl);

  void clearError() {
    if (state.hasError) state = const AuthState.idle();
  }

  /// Ejecuta una operación de autenticación gestionando estado y errores.
  Future<bool> _run(Future<AuthResult> Function() operation) async {
    state = const AuthState.submitting();
    try {
      final AuthResult result = await operation();
      return switch (result) {
        AuthSuccess() => _succeed(),
        AuthFailure(:final message) => _fail(message),
      };
    } catch (error) {
      // Las excepciones ya vienen tipadas desde el repositorio; esto cubre
      // fallos inesperados para que nunca lleguen crudos a la UI.
      return _fail('No se pudo completar la operación. Inténtalo de nuevo.');
    }
  }

  bool _succeed() {
    state = const AuthState.idle();
    return true;
  }

  bool _fail(String message) {
    state = AuthState.failed(message);
    return false;
  }
}

final NotifierProvider<AuthController, AuthState> authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

// ══════════════════════════════════════════════════════════════════════════
//  Preferencias ligadas a la sesión
// ══════════════════════════════════════════════════════════════════════════

/// Contenido para adultos habilitado (preferencia del dispositivo).
///
/// Se expone aquí porque el catálogo la necesita para filtrar listados.
final Provider<bool> showAdultContentProvider = Provider<bool>(
  (Ref ref) => ref.watch(adultContentProvider),
);

/// Idioma configurado, útil para mostrarlo en Ajustes.
final Provider<String> catalogLanguageProvider = Provider<String>(
  (Ref ref) => ref.watch(appConfigProvider).language,
);

/// `true` si el catálogo es el real de TMDB y no el de demostración.
final Provider<bool> isLiveCatalogProvider = Provider<bool>(
  (Ref ref) => ref.watch(mediaRepositoryProvider).isLive,
);
