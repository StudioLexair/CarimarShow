import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Autenticación local sin servidor.
///
/// Cubre dos casos:
///  1. **Modo demo**: no hay Supabase configurado, pero la app debe seguir siendo
///     usable y «Mi lista» debe persistir en el dispositivo.
///  2. **Sesión de invitado** explícita, aunque exista backend.
///
/// Almacena un único perfil en `shared_preferences`. No hay contraseñas ni
/// hashes: no es un sistema de seguridad, es persistencia de preferencias. Si se
/// configura Supabase, esta clase deja de usarse.
class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository({SharedPreferences? preferences}) : _prefs = preferences;

  static const String _storageKey = 'sinflix.local.user';

  SharedPreferences? _prefs;
  AppUser? _current;

  final StreamController<AppUser?> _controller =
      StreamController<AppUser?>.broadcast();

  /// Inyecta las preferencias ya cargadas y restaura la sesión guardada.
  ///
  /// Se llama desde el arranque de la app; evita leer disco en cada acceso.
  Future<void> initialize(SharedPreferences preferences) async {
    _prefs = preferences;
    _current = _decode(preferences.getString(_storageKey));
  }

  @override
  bool get isRemoteEnabled => false;

  @override
  Stream<AppUser?> authStateChanges() async* {
    // Se emite de inmediato el estado restaurado y después los cambios.
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<AppUser?> currentUser() async => _current;

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) => _createLocalSession(
    displayName: _nameFromEmail(email),
    email: email.trim(),
  );

  @override
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) =>
      _createLocalSession(displayName: displayName.trim(), email: email.trim());

  @override
  Future<AuthResult> signInAsGuest({String? displayName}) =>
      _createLocalSession(
        displayName: (displayName == null || displayName.trim().isEmpty)
            ? 'Invitado'
            : displayName.trim(),
      );

  @override
  Future<AuthResult> sendPasswordReset(String email) async => const AuthFailure(
    'Sin backend configurado no se pueden enviar correos. '
    'Tu sesión se guarda en este dispositivo.',
  );

  @override
  Future<void> updateProfile({String? displayName, String? avatarUrl}) async {
    final AppUser? current = _current;
    if (current == null) return;
    final AppUser updated = current.copyWith(
      displayName: displayName ?? current.displayName,
      avatarUrl: avatarUrl ?? current.avatarUrl,
    );
    await _persist(updated);
  }

  @override
  Future<void> signOut() async {
    _current = null;
    await _prefs?.remove(_storageKey);
    _controller.add(null);
  }

  // ══════════════════════════════════════════════════════════════════════

  Future<AuthResult> _createLocalSession({
    required String displayName,
    String email = '',
  }) async {
    final AppUser user = AppUser(
      id: 'local-user',
      email: email,
      displayName: displayName,
      isGuest: true,
      emailVerified: false,
      createdAt: DateTime.now(),
    );
    await _persist(user);
    return AuthSuccess(user);
  }

  Future<void> _persist(AppUser user) async {
    _current = user;
    await _prefs?.setString(_storageKey, jsonEncode(_encode(user)));
    _controller.add(user);
  }

  static Map<String, dynamic> _encode(AppUser user) => <String, dynamic>{
    'id': user.id,
    'email': user.email,
    'displayName': user.displayName,
    'avatarUrl': user.avatarUrl,
    'isGuest': user.isGuest,
    'createdAt': user.createdAt?.toIso8601String(),
    'themeMode': user.preferences.themeMode,
    'adultContent': user.preferences.adultContent,
  };

  static AppUser? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final String displayName =
          (decoded['displayName'] as String?)?.trim() ?? '';
      return AppUser(
        id: (decoded['id'] as String?) ?? 'local-user',
        email: (decoded['email'] as String?) ?? '',
        displayName: displayName.isEmpty ? 'Invitado' : displayName,
        avatarUrl: decoded['avatarUrl'] as String?,
        isGuest: (decoded['isGuest'] as bool?) ?? true,
        createdAt: decoded['createdAt'] == null
            ? null
            : DateTime.tryParse(decoded['createdAt'] as String),
        preferences: UserPreferences(
          themeMode: (decoded['themeMode'] as String?) ?? 'system',
          adultContent: (decoded['adultContent'] as bool?) ?? false,
        ),
      );
    } catch (_) {
      // Datos corruptos: mejor empezar limpio que bloquear el arranque.
      return null;
    }
  }

  static String _nameFromEmail(String email) {
    final String local = email.trim().split('@').first;
    if (local.isEmpty) return 'Invitado';
    return local
        .replaceAll(RegExp(r'[._\-+]+'), ' ')
        .trim()
        .split(' ')
        .where((String p) => p.isNotEmpty)
        .map((String p) => p[0].toUpperCase() + p.substring(1))
        .join(' ');
  }

  @override
  void dispose() {
    _controller.close();
  }
}
