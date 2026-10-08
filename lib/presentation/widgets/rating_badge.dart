import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

/// Insignia de puntuación con color según el valor.
///
/// El código de color (verde ≥ 7, ámbar ≥ 5.5, rojo por debajo) permite
/// recorrer una rejilla de pósters y detectar de un vistazo qué títulos están
/// bien valorados, sin leer los números.
class RatingBadge extends StatelessWidget {
  const RatingBadge({
    required this.voteAverage,
    this.voteCount,
    this.size = RatingBadgeSize.regular,
    this.showIcon = true,
    super.key,
  });

  const RatingBadge.small(this.voteAverage, {this.voteCount, super.key})
    : size = RatingBadgeSize.small,
      showIcon = true;

  final double voteAverage;
  final int? voteCount;
  final RatingBadgeSize size;
  final bool showIcon;

  bool get hasValue => voteAverage > 0;

  /// Color semáforo según la puntuación.
  Color get color {
    if (!hasValue) return context.pal.textDisabled;
    if (voteAverage >= 7.5) return AppColors.success;
    if (voteAverage >= 6) return const Color(0xFF9BE15D);
    if (voteAverage >= 4.5) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    if (!hasValue) return const SizedBox.shrink();

    final double fontSize = switch (size) {
      RatingBadgeSize.small => 11,
      RatingBadgeSize.regular => 12.5,
      RatingBadgeSize.large => 15,
    };
    final double iconSize = switch (size) {
      RatingBadgeSize.small => 11,
      RatingBadgeSize.regular => 13,
      RatingBadgeSize.large => 16,
    };
    final EdgeInsets padding = switch (size) {
      RatingBadgeSize.small => const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2.5,
      ),
      RatingBadgeSize.regular => const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      RatingBadgeSize.large => const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
    };

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showIcon) ...<Widget>[
            Icon(Icons.star_rounded, size: iconSize, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            Formatters.vote(voteAverage),
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

enum RatingBadgeSize { small, regular, large }

/// Etiqueta pequeña y translúcida para metadatos (año, género, duración…).
class MetaChip extends StatelessWidget {
  const MetaChip(this.label, {this.icon, super.key});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: context.pal.surfaceHighest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: AppColors.textPrimary),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta de tipo (PELÍCULA / SERIE) para listados mixtos.
class MediaTypeTag extends StatelessWidget {
  const MediaTypeTag({required this.isTv, super.key});

  final bool isTv;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: (isTv ? AppColors.crimson : const Color(0xFF3D7BFF)).withValues(
          alpha: 0.92,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        isTv ? 'SERIE' : 'PELÍCULA',
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.7,
          color: Colors.white,
          height: 1.2,
        ),
      ),
    );
  }
}
