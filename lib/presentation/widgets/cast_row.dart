import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/poster_image.dart';
import '../../core/widgets/section_header.dart';
import '../../domain/entities/cast_member.dart';

/// Carrusel horizontal del reparto principal.
class CastRow extends StatelessWidget {
  const CastRow({required this.cast, super.key});

  final List<CastMember> cast;

  @override
  Widget build(BuildContext context) {
    if (cast.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SectionHeader(title: 'Reparto principal'),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: cast.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: 16),
            itemBuilder: (BuildContext context, int index) {
              final CastMember member = cast[index];
              return SizedBox(
                width: 88,
                child: Column(
                  children: <Widget>[
                    ProfileImage(
                      imagePath: member.profilePath,
                      name: member.name,
                      seed: member.id,
                      size: 76,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      member.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: context.pal.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      member.subtitle,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.2,
                        color: context.pal.textDisabled,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
