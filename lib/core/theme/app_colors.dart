import 'package:flutter/material.dart';

/// Paleta de CarimarShow.
///
/// Sacada del logotipo que aportó el cliente: turquesa caribeño como acento de
/// marca sobre un fondo azul muy oscuro (no negro puro) para que los pósters
/// sigan siendo los protagonistas. El ámbar queda reservado para valoraciones.
///
/// Los nombres `crimson*` se conservan como alias históricos porque los usan
/// decenas de widgets; apuntan al mismo turquesa que `accent*`.
abstract final class AppColors {
  // ── Marca (turquesa del logotipo) ─────────────────────────────────────
  static const Color accent = Color(0xFF1CA9C9);
  static const Color accentDeep = Color(0xFF0E7C96);
  static const Color accentLight = Color(0xFF6FD3E3);

  /// Menta claro del logotipo, para superficies destacadas en tema claro.
  static const Color mint = Color(0xFFE4F1DA);

  /// Alias históricos del acento de marca.
  static const Color crimson = accent;
  static const Color crimsonDark = accentDeep;
  static const Color crimsonLight = accentLight;

  /// Ámbar usado exclusivamente para puntuaciones y destacados.
  static const Color gold = Color(0xFFFFC53D);

  // ── Superficies (azul noche con tinte turquesa) ───────────────────────
  static const Color background = Color(0xFF071A20);
  static const Color surface = Color(0xFF0C222B);
  static const Color surfaceHigh = Color(0xFF123039);
  static const Color surfaceHighest = Color(0xFF1A3D48);
  static const Color outline = Color(0xFF24505C);

  // ── Texto ─────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF2FBFC);
  static const Color textSecondary = Color(0xFF9FC3CC);
  static const Color textDisabled = Color(0xFF5E8590);

  // ── Estado ────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF2ED573);
  static const Color warning = Color(0xFFFFA502);
  static const Color danger = Color(0xFFFF4757);

  // ── Degradados ────────────────────────────────────────────────────────
  /// Degradado vertical para fundir los fondos con el contenido.
  static const LinearGradient backdropScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Color(0x00071A20),
      Color(0x66071A20),
      Color(0xCC071A20),
      Color(0xFF071A20),
    ],
    stops: <double>[0.0, 0.45, 0.78, 1.0],
  );

  /// Degradado de marca para pósters sin imagen (modo demo).
  static const List<List<Color>> posterPlaceholders = <List<Color>>[
    <Color>[Color(0xFF0E4C5C), Color(0xFF082A33)],
    <Color>[Color(0xFF123330), Color(0xFF0C1A1A)],
    <Color>[Color(0xFF164050), Color(0xFF0E2530)],
    <Color>[Color(0xFF1D5A6B), Color(0xFF0F303A)],
    <Color>[Color(0xFF2A6B5E), Color(0xFF12332C)],
    <Color>[Color(0xFF14506B), Color(0xFF0B2A38)],
  ];

  /// Elige un degradado estable para un identificador dado.
  static List<Color> placeholderFor(int seed) =>
      posterPlaceholders[seed.abs() % posterPlaceholders.length];
}
