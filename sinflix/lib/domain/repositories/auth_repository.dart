import '../entities/app_user.dart';

/// Resultado de una operación de autenticación.
sealed class AuthResult {
  const AuthResult();
}

/// Operación completada con éxito.
class AuthSuccess extends AuthResult {
  const AuthSuccess(this.user);
  final AppUser user;
}

/// Operación fallida, con un mensaje ya apto para mostrar al usuario.
class AuthFailure extends AuthResult {
  const AuthFailure(this.message, {this.detail, this.isNetwork = false});

  final String message;
  final String? detail;

  /// `true` si el fallo fue de conexión y tiene sentido reintentar.
  final bool isNetwork;
}

/// Contrato de autenticación.
///
/// Dos implementaciones: Supabase (cuentas reales y sincronizadas) y local
/// (sesión de invitado persistida en el dispositivo, para modo demo o si no
/// hay backend). Ambas se intercambian en tiempo de ejecución según la config.
abstract interface class AuthRepository {
  /// Emite el usuario actual, o `null` si no hay sesión.
  ///
  /// El primer evento llega en cuanto se resuelve la sesión persistida.
  Stream<AppUser?> authStateChanges();

  /// Sesión actual sin esperar al stream.
  Future<AppUser?> currentUser();

  Future<AuthResult> signIn({required String email, required String password});

  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  /// Inicia una sesión local sin cuenta ni servidor.
  Future<AuthResult> signInAsGuest({String? displayName});

  Future<AuthResult> sendPasswordReset(String email);

  Future<void> updateProfile({String? displayName, String? avatarUrl});

  Future<void> signOut();

  /// `true` si las cuentas reales están disponibles (backend configurado).
  bool get isRemoteEnabled;

  void dispose() {}
}
