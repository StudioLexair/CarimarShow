import 'package:equatable/equatable.dart';

/// Usuario de la aplicación, independiente del proveedor de autenticación.
///
/// Puede representar una cuenta real (Supabase) o una sesión local de invitado
/// (modo demo / sin backend). La UI no distingue entre ambas.
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.isGuest = false,
    this.emailVerified = false,
    this.createdAt,
    this.preferences = const UserPreferences(),
  });

  /// Identificador del proveedor (UUID de Supabase) o `guest` para invitados.
  final String id;

  /// Correo, o cadena vacía en sesiones de invitado.
  final String email;

  final String displayName;
  final String? avatarUrl;

  /// `true` si es una sesión local sin cuenta creada.
  final bool isGuest;

  final bool emailVerified;
  final DateTime? createdAt;
  final UserPreferences preferences;

  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;

  /// Iniciales para el avatar generado, p. ej. `María López` → `ML`.
  String get initials {
    final List<String> parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
    bool? isGuest,
    bool? emailVerified,
    DateTime? createdAt,
    UserPreferences? preferences,
  }) => AppUser(
    id: id ?? this.id,
    email: email ?? this.email,
    displayName: displayName ?? this.displayName,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    isGuest: isGuest ?? this.isGuest,
    emailVerified: emailVerified ?? this.emailVerified,
    createdAt: createdAt ?? this.createdAt,
    preferences: preferences ?? this.preferences,
  );

  @override
  List<Object?> get props => <Object?>[
    id,
    email,
    displayName,
    avatarUrl,
    isGuest,
    emailVerified,
    createdAt,
    preferences,
  ];
}

/// Preferencias guardadas por usuario.
class UserPreferences extends Equatable {
  const UserPreferences({
    this.themeMode = 'system',
    this.adultContent = false,
    this.defaultMediaType = 'movie',
  });

  /// `system` | `light` | `dark`
  final String themeMode;

  /// Mostrar contenido para adultos en los listados.
  final bool adultContent;

  /// `movie` | `tv` — pestaña inicial al abrir el catálogo.
  final String defaultMediaType;

  UserPreferences copyWith({
    String? themeMode,
    bool? adultContent,
    String? defaultMediaType,
  }) => UserPreferences(
    themeMode: themeMode ?? this.themeMode,
    adultContent: adultContent ?? this.adultContent,
    defaultMediaType: defaultMediaType ?? this.defaultMediaType,
  );

  @override
  List<Object?> get props => <Object?>[
    themeMode,
    adultContent,
    defaultMediaType,
  ];
}
