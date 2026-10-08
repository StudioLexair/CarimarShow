import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/errors/app_exception.dart' as app;
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Autenticación real contra Supabase.
///
/// El perfil (nombre visible, avatar) vive en la tabla pública `profiles` con
/// una fila por usuario y políticas RLS, para no depender únicamente de los
/// metadatos de `auth.users`. Si la fila no existe, se crea con un trigger.
/// Ver `supabase/migrations/0001_initial_schema.sql`.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({required this.client});

  final sb.SupabaseClient client;

  @override
  bool get isRemoteEnabled => true;

  @override
  Stream<AppUser?> authStateChanges() {
    // El try/catch va DENTRO del asyncMap: `handleError` no puede sustituir el
    // valor emitido, así que un fallo al proyectar el usuario se convierte aquí
    // en una sesión ausente y la UI vuelve a la pantalla de acceso.
    return client.auth.onAuthStateChange.asyncMap((sb.AuthState state) async {
      try {
        final sb.User? user = state.session?.user;
        if (user == null) return null;
        return await _toAppUser(user);
      } catch (_) {
        return null;
      }
    });
  }

  @override
  Future<AppUser?> currentUser() async {
    final sb.User? user = client.auth.currentUser;
    return user == null ? null : _toAppUser(user);
  }

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final sb.AuthResponse response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final sb.User? user = response.user;
      if (user == null) {
        return const AuthFailure(
          'No se pudo iniciar sesión. Inténtalo de nuevo.',
        );
      }
      return AuthSuccess(await _toAppUser(user));
    } on sb.AuthException catch (error) {
      return AuthFailure(_translate(error.message), detail: error.message);
    } catch (error) {
      return _fromUnknown(error);
    }
  }

  @override
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final sb.AuthResponse response = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: <String, dynamic>{'display_name': displayName.trim()},
      );
      final sb.User? user = response.user;
      if (user == null) {
        return const AuthFailure(
          'No se pudo crear la cuenta. Inténtalo de nuevo.',
        );
      }
      // Si el proyecto exige confirmación por correo no hay sesión todavía.
      if (response.session == null) {
        return const AuthFailure(
          'Cuenta creada. Revisa tu correo para confirmarla antes de entrar.',
        );
      }
      return AuthSuccess(await _toAppUser(user));
    } on sb.AuthException catch (error) {
      return AuthFailure(_translate(error.message), detail: error.message);
    } catch (error) {
      return _fromUnknown(error);
    }
  }

  /// Supabase no contempla invitados: se delega en la implementación local.
  ///
  /// Se mantiene el método para cumplir el contrato; el proveedor de la app
  /// elige `LocalAuthRepository` cuando se quiere una sesión de invitado.
  @override
  Future<AuthResult> signInAsGuest({String? displayName}) async =>
      const AuthFailure(
        'El modo invitado no está disponible con cuentas remotas.',
      );

  @override
  Future<AuthResult> sendPasswordReset(String email) async {
    try {
      await client.auth.resetPasswordForEmail(email.trim());
      return AuthSuccess(
        AppUser(id: 'reset', email: email.trim(), displayName: email.trim()),
      );
    } on sb.AuthException catch (error) {
      return AuthFailure(_translate(error.message), detail: error.message);
    } catch (error) {
      return _fromUnknown(error);
    }
  }

  @override
  Future<void> updateProfile({String? displayName, String? avatarUrl}) async {
    final sb.User? user = client.auth.currentUser;
    if (user == null) {
      throw const app.AuthException(message: 'No hay ninguna sesión activa');
    }
    try {
      await client.auth.updateUser(
        sb.UserAttributes(
          data: <String, dynamic>{
            'display_name': ?displayName?.trim(),
            'avatar_url': ?avatarUrl,
          },
        ),
      );
      if (displayName != null || avatarUrl != null) {
        await client.from('profiles').upsert(<String, dynamic>{
          'id': user.id,
          'display_name': ?displayName?.trim(),
          'avatar_url': ?avatarUrl,
        });
      }
    } on sb.AuthException catch (error, stackTrace) {
      throw app.AuthException(
        message: _translate(error.message),
        detail: error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Internos
  // ══════════════════════════════════════════════════════════════════════

  /// Convierte el usuario de Supabase en [AppUser], completando con la tabla
  /// `profiles` cuando los metadatos no traen nombre visible.
  Future<AppUser> _toAppUser(sb.User user) async {
    final Map<String, dynamic> metadata =
        user.userMetadata ?? const <String, dynamic>{};

    String displayName = (metadata['display_name'] as String?)?.trim() ?? '';

    String? avatarUrl = metadata['avatar_url'] as String?;

    // Los metadatos solo se rellenan al registrarse; si se editaron desde otro
    // dispositivo, la fuente fiable es la tabla `profiles`.
    if (displayName.isEmpty || avatarUrl == null) {
      final Map<String, dynamic>? profile = await _fetchProfile(user.id);
      if (profile != null) {
        displayName = displayName.isEmpty
            ? ((profile['display_name'] as String?)?.trim() ?? '')
            : displayName;
        avatarUrl ??= profile['avatar_url'] as String?;
      }
    }

    if (displayName.isEmpty) {
      displayName = _nameFromEmail(user.email);
    }

    return AppUser(
      id: user.id,
      email: user.email ?? '',
      displayName: displayName,
      avatarUrl: avatarUrl,
      isGuest: false,
      emailVerified: user.emailConfirmedAt != null,
      createdAt: DateTime.tryParse(user.createdAt),
      preferences: const UserPreferences(),
    );
  }

  Future<Map<String, dynamic>?> _fetchProfile(String userId) async {
    try {
      final dynamic row = await client
          .from('profiles')
          .select('display_name, avatar_url')
          .eq('id', userId)
          .maybeSingle();
      return row is Map<String, dynamic> ? row : null;
    } catch (_) {
      // La tabla puede no existir aún si no se han aplicado las migraciones.
      // No es un error fatal: se usa el correo como nombre visible.
      return null;
    }
  }

  static String _nameFromEmail(String? email) {
    if (email == null || email.isEmpty) return 'Usuario';
    final String local = email.split('@').first;
    final String cleaned = local.replaceAll(RegExp(r'[._\-+]+'), ' ').trim();
    if (cleaned.isEmpty) return 'Usuario';
    return cleaned
        .split(' ')
        .where((String p) => p.isNotEmpty)
        .map((String p) => p[0].toUpperCase() + p.substring(1))
        .join(' ');
  }

  /// Convierte mensajes técnicos de Supabase en texto comprensible.
  static String _translate(String message) {
    final String lower = message.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (lower.contains('already registered') ||
        lower.contains('already been registered')) {
      return 'Ese correo ya tiene una cuenta. Inicia sesión.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Confirma tu correo antes de iniciar sesión.';
    }
    if (lower.contains('password') && lower.contains('short')) {
      return 'La contraseña es demasiado corta (mínimo 6 caracteres).';
    }
    if (lower.contains('rate limit') || lower.contains('too many requests')) {
      return 'Demasiados intentos seguidos. Espera un minuto.';
    }
    if (lower.contains('failed to fetch') ||
        lower.contains('socket') ||
        lower.contains('network')) {
      return 'No se pudo conectar. Comprueba tu conexión.';
    }
    return message;
  }

  static AuthFailure _fromUnknown(Object error) {
    if (error is sb.PostgrestException) {
      return AuthFailure(_translate(error.message), detail: error.message);
    }
    return AuthFailure(
      'No se pudo completar la operación.',
      detail: error.toString(),
      isNetwork: true,
    );
  }

  @override
  void dispose() {}
}
