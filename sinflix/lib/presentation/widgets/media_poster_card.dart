import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/poster_image.dart';
import '../../domain/entities/media_id.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/media_type.dart';
import '../providers/media_providers.dart';
import '../providers/watchlist_providers.dart';
import 'rating_badge.dart';
import 'watchlist_toggle.dart';

/// Tarjeta de póster: la unidad visual básica de toda la app.
///
/// Se usa igual en carruseles horizontales y en rejillas. Incluye el botón de
/// «Mi lista» superpuesto, que es el gesto más frecuente y debe estar siempre a
/// mano sin tener que entrar en la ficha.
class MediaPosterCard extends ConsumerWidget {
  const MediaPosterCard({
    required this.item,
    this.width = 132,
    this.showTitle = true,
    this.showYear = true,
    this.showRating = true,
    this.showTypeTag = false,
    this.showWatchlistButton = true,
    this.onTap,
    super.key,
  });

  final MediaItem item;

  /// Ancho fijo. En rejillas se ignora y manda la restricción del padre.
  final double width;

  final bool showTitle;
  final bool showYear;
  final bool showRating;

  /// Etiqueta PELÍCULA/SERIE, útil en listados mixtos como la búsqueda.
  final bool showTypeTag;

  final bool showWatchlistButton;

  /// Acción al tocar. Por defecto navega a la ficha del título.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MediaId id = mediaIdOf(item);
    final List<String> genres = ref.watch(itemGenreNamesProvider(item));

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _PosterFrame(
            item: item,
            showTypeTag: showTypeTag,
            showRating: showRating,
            showWatchlistButton: showWatchlistButton,
            watchlistId: id,
            onTap: onTap ?? () => context.push(id.route),
          ),
          if (showTitle) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              item.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleSmall?.copyWith(height: 1.25),
            ),
            if (showYear || genres.isNotEmpty) ...<Widget>[
              const SizedBox(height: 3),
              Text(
                Formatters.join(<String?>[
                  if (showYear) Formatters.year(item.releaseDate),
                  if (genres.isNotEmpty) genres.first,
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(
                  color: AppColors.textDisabled,
                  fontSize: 11.5,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PosterFrame extends StatelessWidget {
  const _PosterFrame({
    required this.item,
    required this.showTypeTag,
    required this.showRating,
    required this.showWatchlistButton,
    required this.watchlistId,
    required this.onTap,
  });

  final MediaItem item;
  final bool showTypeTag;
  final bool showRating;
  final bool showWatchlistButton;
  final MediaId watchlistId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: Material(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              PosterImage(
                imagePath: item.posterPath,
                title: item.displayTitle,
                seed: item.id,
                size: 'w342',
              ),

              // Sombreado inferior para que los textos se lean sobre la imagen.
              if (showRating || showTypeTag)
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: IgnorePointer(
                    child: SizedBox(
                      height: 74,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[Colors.transparent, Colors.black87],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              if (showTypeTag)
                Positioned(
                  left: 8,
                  top: 8,
                  child: MediaTypeTag(isTv: item.type == MediaType.tv),
                ),

              if (showRating && item.hasVote)
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: RatingBadge(
                    voteAverage: item.voteAverage,
                    size: RatingBadgeSize.small,
                  ),
                ),

              if (showWatchlistButton)
                Positioned(
                  right: 6,
                  top: 6,
                  child: WatchlistToggle(
                    mediaId: watchlistId,
                    media: item,
                    size: 34,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta ancha con fondo 16:9, para «Continuar viendo» y destacados.
class MediaBackdropCard extends StatelessWidget {
  const MediaBackdropCard({
    required this.item,
    this.width = 260,
    this.subtitle,
    this.progress,
    this.onTap,
    super.key,
  });

  final MediaItem item;
  final double width;
  final String? subtitle;

  /// Progreso de visionado 0–1, para pintar la barra inferior.
  final double? progress;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Material(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap ?? () => context.push(mediaIdOf(item).route),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    BackdropImage(
                      imagePath: item.backdropPath ?? item.posterPath,
                      title: item.displayTitle,
                      seed: item.id,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.backdropScrim,
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: progress != null ? 18 : 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  item.displayTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              if (item.hasVote) ...<Widget>[
                                const SizedBox(width: 8),
                                RatingBadge.small(item.voteAverage),
                              ],
                            ],
                          ),
                          if (subtitle != null &&
                              subtitle!.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 3),
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (progress != null)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 8,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress!.clamp(0, 1),
                            minHeight: 3.5,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.crimson,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: WatchlistToggle(
                        mediaId: mediaIdOf(item),
                        media: item,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
