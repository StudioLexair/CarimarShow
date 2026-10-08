import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../constants/tmdb_constants.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../utils/tmdb_images.dart';

/// Imagen de catálogo con caché, esqueleto de carga y reserva elegante.
///
/// Cuando TMDB no aporta imagen (o en modo demo, donde nunca la hay) se pinta un
/// degradado determinista derivado del id más el título. Así la interfaz nunca
/// muestra el típico icono roto: una rejilla de pósters sin imágenes sigue
/// viéndose como una interfaz terminada.
class PosterImage extends StatelessWidget {
  const PosterImage({
    required this.imagePath,
    required this.title,
    this.seed = 0,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.size = TmdbImageSize.posterMedium,
    this.showTitleFallback = true,
    super.key,
  });

  /// Ruta relativa del CDN, p. ej. `/abc123.jpg`, o `null`.
  final String? imagePath;

  /// Título, usado como reserva visual y como descripción semántica.
  final String title;

  /// Semilla del degradado de reserva. Pasa el id de TMDB para que sea estable.
  final int seed;

  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Tamaño de imagen a pedir al CDN.
  final String size;

  /// Pintar el título sobre el degradado cuando no hay imagen.
  final bool showTitleFallback;

  @override
  Widget build(BuildContext context) {
    final String? resolved = TmdbImages.url(imagePath, size);
    final Widget fallback = _GradientPlaceholder(
      title: title,
      seed: seed,
      showTitle: showTitleFallback,
    );

    final Widget image = resolved == null
        ? fallback
        : CachedNetworkImage(
            imageUrl: resolved,
            fit: fit,
            fadeInDuration: const Duration(milliseconds: 180),
            fadeOutDuration: const Duration(milliseconds: 80),
            placeholder: (BuildContext context, String url) =>
                _ShimmerPlaceholder(borderRadius: borderRadius),
            errorWidget: (BuildContext context, String url, Object error) =>
                fallback,
          );

    final Widget clipped = borderRadius == null
        ? image
        : ClipRRect(borderRadius: borderRadius!, child: image);

    return Semantics(label: title, image: true, child: clipped);
  }
}

/// Fondo (backdrop) de 16:9 con la misma lógica de reserva.
class BackdropImage extends StatelessWidget {
  const BackdropImage({
    required this.imagePath,
    required this.title,
    this.seed = 0,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String? imagePath;
  final String title;
  final int seed;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return PosterImage(
      imagePath: imagePath,
      title: title,
      seed: seed,
      fit: fit,
      size: TmdbImageSize.backdropLarge,
      showTitleFallback: false,
    );
  }
}

/// Retrato de una persona del reparto.
class ProfileImage extends StatelessWidget {
  const ProfileImage({
    required this.imagePath,
    required this.name,
    this.seed = 0,
    this.size = 56,
    super.key,
  });

  final String? imagePath;
  final String name;
  final int seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String? resolved = TmdbImages.profile(imagePath);

    if (resolved == null) {
      final List<Color> colors = AppColors.placeholderFor(seed);
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: colors.first,
        child: Text(
          _initials(name),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontWeight: FontWeight.w700,
            fontSize: size * 0.36,
          ),
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: resolved,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (BuildContext context, String url) => Container(
          width: size,
          height: size,
          color: context.pal.surfaceHigh,
        ),
        errorWidget: (BuildContext context, String url, Object error) =>
            CircleAvatar(
              radius: size / 2,
              backgroundColor: context.pal.surfaceHigh,
            ),
      ),
    );
  }

  static String _initials(String name) {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

/// Degradado estable usado cuando no hay imagen disponible.
class _GradientPlaceholder extends StatelessWidget {
  const _GradientPlaceholder({
    required this.title,
    required this.seed,
    this.showTitle = true,
  });

  final String title;
  final int seed;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = AppColors.placeholderFor(seed);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: showTitle
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

/// Esqueleto animado con la forma del hueco que va a ocupar la imagen.
class _ShimmerPlaceholder extends StatelessWidget {
  const _ShimmerPlaceholder({this.borderRadius});

  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final Widget box = ColoredBox(color: context.pal.surfaceHigh);
    return Shimmer.fromColors(
      baseColor: context.pal.surfaceHigh,
      highlightColor: context.pal.surfaceHighest,
      child: borderRadius == null
          ? box
          : ClipRRect(borderRadius: borderRadius!, child: box),
    );
  }
}

/// Bloque de esqueleto genérico para listas y fichas en carga.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    this.width,
    this.height,
    this.borderRadius = 10,
    super.key,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: context.pal.surfaceHigh,
      highlightColor: context.pal.surfaceHighest,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: context.pal.surfaceHigh,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Rejilla de esqueletos con forma de póster, para el estado de carga.
class PosterGridSkeleton extends StatelessWidget {
  const PosterGridSkeleton({
    this.itemCount = 8,
    this.aspectRatio = 2 / 3,
    super.key,
  });

  final int itemCount;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = context.posterColumns;
        const double spacing = 12;
        final double itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: aspectRatio,
          ),
          itemCount: itemCount,
          itemBuilder: (BuildContext context, int index) =>
              ShimmerBox(width: itemWidth, borderRadius: 14),
        );
      },
    );
  }
}
