import 'package:flutter/material.dart';

/// Paleta de CarimarShow.
///
/// Base casi negra para que los pósters sean los protagonistas, con un carmesí
/// saturado como acento de marca y un ámbar reservado para valoraciones.
abstract final class AppColors {
  // ── Marca ────────────────────────────────────────────────────────────
  static const Color crimson = Color(0xFFFF2E4D);
  static const Color crimsonDark = Color(0xFFC2102C);
  static const Color crimsonLight = Color(0xFFFF7085);

  /// Ámbar usado exclusivamente para puntuaciones y destacados.
  static const Color gold = Color(0xFFFFC53D);

  // ── Superficies ───────────────────────────────────────────────────────
  static const Color background = Color(0xFF08080C);
  static const Color surface = Color(0xFF101017);
  static const Color surfaceHigh = Color(0xFF181822);
  static const Color surfaceHighest = Color(0xFF22222E);
  static const Color outline = Color(0xFF2E2E3C);

  // ── Texto ─────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF4F4F7);
  static const Color textSecondary = Color(0xFFA8A8B8);
  static const Color textDisabled = Color(0xFF6A6A7A);

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
      Color(0x0008080C),
      Color(0x6608080C),
      Color(0xCC08080C),
      Color(0xFF08080C),
    ],
    stops: <double>[0.0, 0.45, 0.78, 1.0],
  );

  /// Degradado de marca para pósters sin imagen (modo demo).
  static const List<List<Color>> posterPlaceholders = <List<Color>>[
    <Color>[Color(0xFF3A1C2A), Color(0xFF1A1024)],
    <Color>[Color(0xFF16283C), Color(0xFF0E1520)],
    <Color>[Color(0xFF2C1E3A), Color(0xFF14101E)],
    <Color>[Color(0xFF123330), Color(0xFF0C1A1A)],
    <Color>[Color(0xFF3A2418), Color(0xFF1C120C)],
    <Color>[Color(0xFF231C3C), Color(0xFF110E1E)],
  ];

  /// Elige un degradado estable para un identificador dado.
  static List<Color> placeholderFor(int seed) =>
      posterPlaceholders[seed.abs() % posterPlaceholders.length];
}
