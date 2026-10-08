import 'package:flutter/material.dart';

import '../../../domain/entities/media_type.dart';
import '../catalog/catalog_screen.dart';

/// Pestaña «Series».
class SeriesScreen extends StatelessWidget {
  const SeriesScreen({super.key});

  @override
  Widget build(BuildContext context) => const CatalogScreen(type: MediaType.tv);
}
