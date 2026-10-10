import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'dart:async';

import '../network/network_probe.dart';
import '../theme/app_theme.dart';
import '../utils/image_cache.dart';
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
class PosterImage extends StatefulWidget {
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
  State<PosterImage> createState() => _PosterImageState();
}

class _PosterImageState extends State<PosterImage> {
  /// Cambiar esta clave fuerza a `CachedNetworkImage` a reintentar la URL
  /// después de haberla evacuado de la caché al fallar.
  int _intento = 0;

  Future<void> _reintentar(String url) async {
    await AppImages.evict(url);
    if (mounted) setState(() => _intento++);
  }

  /// En conexión lenta se pide un tamaño menor al CDN: la misma imagen pesa
  /// ~4 veces menos y llega antes que el usuario pierda la paciencia.
  static String _adaptar(String size) {
    if (NetworkProbe.cachedTier != NetTier.slow) return size;
    return switch (size) {
      TmdbImageSize.posterLarge => TmdbImageSize.posterMedium,
      TmdbImageSize.posterMedium => TmdbImageSize.posterSmall,
      TmdbImageSize.backdropLarge => TmdbImageSize.backdropMedium,
      TmdbImageSize.backdropMedium => TmdbImageSize.backdropSmall,
      _ => size,
    };
  }

  @override
  Widget build(BuildContext context) {
    final String? resolved = TmdbImages.url(
      widget.imagePath,
      _adaptar(widget.size),
    );
    final Widget fallback = _GradientPlaceholder(
      title: widget.title,
      seed: widget.seed,
      showTitle: widget.showTitleFallback,
    );

    final Widget image = resolved == null
        ? fallback
        : kIsWeb
        ? _WebImage(
            key: ValueKey<String>('$resolved#$_intento'),
            url: resolved,
            fit: widget.fit,
            borderRadius: widget.borderRadius,
            autoRestantes: 2 - _intento,
            onRetry: () => _reintentar(resolved),
          )
        : CachedNetworkImage(
            key: ValueKey<String>('$resolved#$_intento'),
            imageUrl: resolved,
            cacheManager: AppImages.manager,
            fit: widget.fit,
            fadeInDuration: const Duration(milliseconds: 220),
            fadeOutDuration: const Duration(milliseconds: 90),
            placeholder: (BuildContext context, String url) =>
                _ShimmerPlaceholder(borderRadius: widget.borderRadius),
            errorWidget: (BuildContext context, String url, Object error) =>
                _RetryTile(
                  borderRadius: widget.borderRadius,
                  autoRestantes: 2 - _intento,
                  onRetry: () => _reintentar(url),
                ),
          );

    final Widget clipped = widget.borderRadius == null
        ? image
        : ClipRRect(borderRadius: widget.borderRadius!, child: image);

    return Semantics(label: widget.title, image: true, child: clipped);
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
      size: TmdbImageSize.backdropMedium,
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
        cacheManager: AppImages.manager,
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
///
/// Lleva el logotipo muy tenue en el centro: mientras carga, el hueco ya se
/// reconoce como parte de CarimarShow y no como un rectángulo roto.
class _ShimmerPlaceholder extends StatelessWidget {
  const _ShimmerPlaceholder({this.borderRadius});

  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final Widget box = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ColoredBox(color: context.pal.surfaceHigh),
        Center(
          child: Opacity(
            opacity: 0.35,
            child: Image.asset(
              'assets/brand/logo.jpeg',
              width: 34,
              height: 34,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
    return Shimmer.fromColors(
      baseColor: context.pal.surfaceHigh,
      highlightColor: context.pal.surfaceHighest,
      child: borderRadius == null
          ? box
          : ClipRRect(borderRadius: borderRadius!, child: box),
    );
  }
}

/// Estado de fallo de una imagen: se ve intencionado y se arregla tocando.
///
/// Antes el fallo enseñaba el mismo degradado que «sin imagen», y una red
/// lenta o un CDN caído se veían como cajas vacías sin explicación. Ahora el
/// hueco dice qué pasa y ofrece el reintento de un toque: se evacúa la URL de
/// la caché y se vuelve a pedir.
class _RetryTile extends StatefulWidget {
  const _RetryTile({this.borderRadius, this.onRetry, this.autoRestantes = 0});

  final BorderRadius? borderRadius;
  final VoidCallback? onRetry;

  /// Reintentos que se lanzan solos (con espera creciente) antes de pedirle
  /// un toque al usuario. En redes malas un fallo puntual se recupera solo y
  /// el usuario ni se entera.
  final int autoRestantes;

  @override
  State<_RetryTile> createState() => _RetryTileState();
}

class _RetryTileState extends State<_RetryTile> {
  @override
  void initState() {
    super.initState();
    if (widget.autoRestantes > 0) {
      final int espera = 400 * (3 - widget.autoRestantes);
      Timer(Duration(milliseconds: espera), () {
        if (mounted) widget.onRetry?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.autoRestantes > 0) {
      return ColoredBox(
        color: context.pal.surfaceHigh,
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final BorderRadius? borderRadius = widget.borderRadius;
    final VoidCallback? onRetry = widget.onRetry;
    return InkWell(
      borderRadius: borderRadius,
      onTap: onRetry,
      child: ColoredBox(
        color: context.pal.surfaceHigh,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.cloud_off_rounded,
                size: 22,
                color: context.pal.textDisabled,
              ),
              const SizedBox(height: 6),
              Text(
                'Toca para reintentar',
                style: TextStyle(
                  fontSize: 10.5,
                  color: context.pal.textDisabled,
                ),
              ),
            ],
          ),
        ),
      ),
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

/// En web, imagen de red SIN plugin de caché.
///
/// `cached_network_image` apoya su proveedor web en `flutter_cache_manager`,
/// que en el navegador no tiene sistema de ficheros: el resultado era que
/// TODAS las imágenes acababan en el tile de «toca para reintentar». Aquí se
/// usa `Image.network`, que delega en la caché HTTP del navegador; el CDN de
/// TMDB sirve `cache-control: max-age=43200`, así que la segunda visita (y el
/// ida-y-vuelta entre pestañas) no vuelve a descargar nada.
class _WebImage extends StatefulWidget {
  const _WebImage({
    required this.url,
    required this.fit,
    required this.autoRestantes,
    required this.onRetry,
    this.borderRadius,
    super.key,
  });

  final String url;
  final BoxFit fit;
  final int autoRestantes;
  final VoidCallback onRetry;
  final BorderRadius? borderRadius;

  @override
  State<_WebImage> createState() => _WebImageState();
}

class _WebImageState extends State<_WebImage> {
  bool _error = false;

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return _RetryTile(
        borderRadius: widget.borderRadius,
        autoRestantes: widget.autoRestantes,
        onRetry: widget.onRetry,
      );
    }
    return Image.network(
      widget.url,
      fit: widget.fit,
      gaplessPlayback: true,
      errorBuilder: (BuildContext context, Object error, StackTrace? st) {
        // Marcar el error fuera del build para no setState durante el build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _error = true);
        });
        return _ShimmerPlaceholder(borderRadius: widget.borderRadius);
      },
      loadingBuilder:
          (BuildContext context, Widget child, ImageChunkEvent? p) =>
              _ShimmerPlaceholder(borderRadius: widget.borderRadius),
      frameBuilder:
          (BuildContext context, Widget child, int? frame, bool sync) {
            if (frame == null) return child;
            return AnimatedOpacity(
              opacity: sync ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: child,
            );
          },
    );
  }
}
