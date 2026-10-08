import 'package:flutter/material.dart';

/// Punto de ruptura y utilidades de diseño adaptable.
///
/// CarimarShow corre en móvil, tablet, escritorio y web, así que el número de
/// columnas de pósters y el tipo de navegación (barra inferior vs. rail
/// lateral) se deciden aquí y en un solo sitio.
abstract final class Breakpoints {
  /// Teléfono en vertical.
  static const double compact = 600;

  /// Tablet pequeña / teléfono en horizontal / ventana estrecha.
  static const double medium = 840;

  /// Tablet grande / escritorio.
  static const double expanded = 1200;

  /// Escritorio ancho.
  static const double large = 1600;
}

/// Clasificación del tamaño de pantalla disponible.
enum ScreenClass {
  compact,
  medium,
  expanded,
  large;

  bool get isCompact => this == ScreenClass.compact;
  bool get isMediumOrLarger => this != ScreenClass.compact;
  bool get isExpandedOrLarger =>
      this == ScreenClass.expanded || this == ScreenClass.large;
}

extension ResponsiveX on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  double get shortestSide => MediaQuery.sizeOf(this).shortestSide;

  ScreenClass get screenClass {
    final double width = screenWidth;
    if (width >= Breakpoints.large) return ScreenClass.large;
    if (width >= Breakpoints.expanded) return ScreenClass.expanded;
    if (width >= Breakpoints.medium) return ScreenClass.medium;
    return ScreenClass.compact;
  }

  bool get isCompact => screenClass.isCompact;
  bool get isTabletOrDesktop => screenClass.isMediumOrLarger;
  bool get isDesktop => screenClass.isExpandedOrLarger;

  /// Muestra la barra de navegación lateral en lugar de la inferior.
  bool get usesNavigationRail => !isCompact;

  /// Columnas para rejillas de pósters según el ancho disponible.
  int get posterColumns => switch (screenClass) {
    ScreenClass.compact => 2,
    ScreenClass.medium => 3,
    ScreenClass.expanded => 5,
    ScreenClass.large => 7,
  };

  /// Columnas para rejillas de fondos (tarjetas anchas).
  int get backdropColumns => switch (screenClass) {
    ScreenClass.compact => 1,
    ScreenClass.medium => 2,
    ScreenClass.expanded => 3,
    ScreenClass.large => 4,
  };

  /// Ancho máximo del contenido, para que en monitores grandes no se estire.
  double get contentMaxWidth => isDesktop ? 1400 : double.infinity;

  /// Margen horizontal cómodo según el dispositivo.
  double get gutter => switch (screenClass) {
    ScreenClass.compact => 16,
    ScreenClass.medium => 24,
    ScreenClass.expanded => 32,
    ScreenClass.large => 48,
  };
}

/// Centra y limita el ancho del contenido en pantallas grandes.
class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
        child: child,
      ),
    );
  }
}
