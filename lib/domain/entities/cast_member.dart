import 'package:equatable/equatable.dart';

/// Miembro del reparto o del equipo técnico.
class CastMember extends Equatable {
  const CastMember({
    required this.id,
    required this.name,
    required this.character,
    this.profilePath,
    this.order = 0,
    this.department,
    this.job,
  });

  final int id;
  final String name;

  /// Personaje interpretado (reparto) o vacío si es equipo técnico.
  final String character;

  final String? profilePath;

  /// Posición en los créditos; TMDB ordena por importancia.
  final int order;

  final String? department;
  final String? job;

  bool get hasPhoto => profilePath != null && profilePath!.isNotEmpty;

  /// Texto secundario: personaje para actores, cargo para técnicos.
  String get subtitle {
    if (character.isNotEmpty) return character;
    final String? role = job;
    if (role != null && role.isNotEmpty) return role;
    return department ?? '';
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    character,
    profilePath,
    order,
    department,
    job,
  ];
}
