import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/poster_image.dart';
import '../../domain/entities/media_item.dart';

/// Carril «Top 10» con números gigantes delineados detrás de cada póster.
///
/// Es el gesto visual que le faltaba a la portada: un carrusel de pósters a
/// secas parece siempre el mismo catálogo, mientras que el ranking numerado
/// se lee de un vistazo y da jerarquía editorial a la pantalla.
class Top10Rail extends StatelessWidget {
  const Top10Rail({
    required this.items,
    this.title = 'Top 10 de la semana',
    super.key,
  });

  final List<MediaItem> items;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final List<MediaItem> top = items.take(10).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Row(
            children: <Widget>[
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: context.pal.textPrimary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 208,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: top.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (BuildContext context, int index) {
              final MediaItem item = top[index];
              return GestureDetector(
                onTap: () =>
                    context.push('/title/${item.type.apiValue}/${item.id}'),
                child: SizedBox(
                  width: 148,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      // El número delineado, medio tapado por el póster: el
                      // truco clásico de los rankings editoriales.
                      Positioned(
                        left: -6,
                        bottom: -14,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 96,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -6,
                            color: Colors.transparent,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 3
                              ..color = context.pal.outline,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: SizedBox(
                          width: 108,
                          child: PosterImage(
                            imagePath: item.posterPath,
                            title: item.displayTitle,
                            seed: item.id,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
