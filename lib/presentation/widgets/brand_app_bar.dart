import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/app_user.dart';
import '../providers/auth_providers.dart';

/// Barra superior con el logotipo y accesos a búsqueda y perfil.
///
/// Se comparte entre las pestañas del shell para no repetir el mismo código en
/// Inicio, Películas, Series y Mi lista.
class BrandAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const BrandAppBar({this.showSearch = true, this.bottom, this.actions, super.key});

  final bool showSearch;

  /// Acciones extra de cada pantalla (p. ej. compartir la lista).
  final List<Widget>? actions;

  /// Pestañas u otro widget que cuelga bajo la barra.
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(currentUserProvider);

    return AppBar(
      bottom: bottom,
      actions: actions,
      titleSpacing: 16,
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _LogoMark(),
          SizedBox(width: 9),
          Text(
            Strings.appName,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        if (showSearch)
          IconButton(
            tooltip: 'Buscar',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push('/search'),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            tooltip: user?.displayName ?? 'Perfil',
            icon: CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.surfaceHigh,
              child: Text(
                user?.initials ?? '?',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            onPressed: () => context.push('/profile'),
          ),
        ),
      ],
    );
  }
}

/// Cuadrado con la «S» de la marca.
class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.crimson,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'S',
        style: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}
