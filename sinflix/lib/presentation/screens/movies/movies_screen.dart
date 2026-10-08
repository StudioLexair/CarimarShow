import 'package:flutter/material.dart';

import '../../../domain/entities/media_type.dart';
import '../catalog/catalog_screen.dart';

/// Pestaña «Películas».
class MoviesScreen extends StatelessWidget {
  const MoviesScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const CatalogScreen(type: MediaType.movie);
}
