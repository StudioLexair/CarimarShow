import 'package:flutter/widgets.dart';

import '../../core/utils/image_cache.dart';
import '../../core/utils/tmdb_images.dart';
import '../../domain/entities/media_item.dart';

/// Precarga en memoria los pósters y fondos de [items] en cuanto el frame
/// está pintado.
///
/// Es lo que hace que el ida-y-vuelta Inicio ↔ Series no vuelva a mostrar
/// esqueletos: las imágenes ya están decodificadas en la caché de Flutter
/// antes de que la pantalla las pida. No pinta nada (SizedBox.shrink).
class PrecacheImages extends StatefulWidget {
  const PrecacheImages({required this.items, this.max = 20, super.key});

  final List<MediaItem> items;
  final int max;

  @override
  State<PrecacheImages> createState() => _PrecacheImagesState();
}

class _PrecacheImagesState extends State<PrecacheImages> {
  bool _lanzado = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _lanzar());
  }

  void _lanzar() {
    if (_lanzado || !mounted) return;
    _lanzado = true;
    final List<MediaItem> items = widget.items.take(widget.max).toList();
    AppImages.precache(
      context,
      items.expand(
        (MediaItem i) => <String?>[
          TmdbImages.poster(i.posterPath),
          TmdbImages.backdrop(i.backdropPath),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
