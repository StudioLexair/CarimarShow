import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/poster_image.dart';
import '../../../core/widgets/section_header.dart';
import '../../../domain/entities/media_details.dart';
import '../../../domain/entities/media_id.dart';
import '../../../domain/entities/media_item.dart';
import '../../../domain/entities/media_video.dart';
import '../../../domain/entities/season.dart';
import '../../../domain/entities/watchlist_item.dart';
import '../../providers/media_providers.dart';
import '../../providers/watchlist_providers.dart';
import '../player/player_screen.dart';
import '../../widgets/cast_row.dart';
import '../../widgets/media_carousel.dart';
import '../../widgets/rating_badge.dart';
import '../../widgets/watchlist_toggle.dart';

/// Ficha completa de un título.
///
/// Una sola petición a TMDB trae ficha, créditos, vídeos, similares y
/// recomendaciones (`append_to_response`), así que la pantalla entera se
/// resuelve con una llamada de red.
class MediaDetailScreen extends ConsumerWidget {
  const MediaDetailScreen({required this.mediaId, super.key});

  final MediaId mediaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MediaDetails> details = ref.watch(
      mediaDetailsProvider(mediaId),
    );

    return Scaffold(
      body: details.when(
        loading: () => const _DetailSkeleton(),
        error: (Object error, StackTrace stackTrace) =>
            _DetailError(error: error, mediaId: mediaId),
        data: (MediaDetails data) =>
            _DetailContent(details: data, mediaId: mediaId),
      ),
    );
  }
}

class _DetailContent extends ConsumerWidget {
  const _DetailContent({required this.details, required this.mediaId});

  final MediaDetails details;
  final MediaId mediaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MediaItem item = details.item;
    final bool inList = ref.watch(isInWatchlistProvider(mediaId));
    final WatchlistItem? entry = ref.watch(watchlistEntryProvider(mediaId));

    // Alto del cabecero proporcional a la pantalla, sin pasarse en escritorio.
    final double expandedHeight = context.isCompact
        ? 300
        : (context.screenWidth * 0.28).clamp(260.0, 420.0);

    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          expandedHeight: expandedHeight,
          pinned: true,
          stretch: true,
          backgroundColor: context.pal.background,
          surfaceTintColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            background: _HeroHeader(details: details),
            expandedTitleScale: 1,
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Buscar',
              icon: const Icon(Icons.search_rounded),
              onPressed: () => context.push('/search'),
            ),
            IconButton(
              tooltip: inList ? 'Quitar de Mi lista' : 'Añadir a Mi lista',
              icon: Icon(
                inList ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
                color: inList ? AppColors.crimson : null,
              ),
              onPressed: () =>
                  ref.read(watchlistControllerProvider.notifier).toggle(item),
            ),
            const SizedBox(width: 4),
          ],
        ),

        // ── Bloque principal ─────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(context.gutter, 16, context.gutter, 0),
            child: _TitleBlock(details: details, entry: entry),
          ),
        ),

        // ── Acciones ─────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(context.gutter, 18, context.gutter, 0),
            child: _ActionBar(details: details, mediaId: mediaId),
          ),
        ),

        // ── Sinopsis ─────────────────────────────────────────────────────
        if (item.hasOverview)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.gutter,
                22,
                context.gutter,
                0,
              ),
              child: Text(item.overview, style: context.text.bodyMedium),
            ),
          ),

        // ── Ficha técnica ────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(context.gutter, 22, context.gutter, 0),
            child: _FactsGrid(details: details),
          ),
        ),

        // ── Palabras clave ───────────────────────────────────────────────
        if (details.keywords.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.gutter,
                20,
                context.gutter,
                0,
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: details.keywords
                    .map(
                      (String keyword) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.pal.surfaceHigh,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: context.pal.outline),
                        ),
                        child: Text(
                          keyword,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: context.pal.textSecondary,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),

        // ── Reparto ──────────────────────────────────────────────────────
        if (details.topCast.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 26),
              child: CastRow(cast: details.topCast),
            ),
          ),

        // ── Temporadas (series) ──────────────────────────────────────────
        if (details.regularSeasons.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 26, left: 0, right: 0),
              child: _SeasonsBlock(
                seriesId: details.id,
                seasons: details.regularSeasons,
                totalEpisodes: details.numberOfEpisodes,
              ),
            ),
          ),

        // ── Similares y recomendaciones ──────────────────────────────────
        if (details.recommendations.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: MediaCarousel(
                title: 'Recomendaciones',
                subtitle: 'Basadas en este título',
                items: details.recommendations,
              ),
            ),
          ),

        if (details.similar.isNotEmpty)
          SliverToBoxAdapter(
            child: MediaCarousel(
              title: 'Títulos similares',
              items: details.similar,
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  Cabecera
// ══════════════════════════════════════════════════════════════════════════

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.details});

  final MediaDetails details;

  @override
  Widget build(BuildContext context) {
    final MediaItem item = details.item;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        BackdropImage(
          imagePath: item.backdropPath ?? item.posterPath,
          title: item.displayTitle,
          seed: item.id,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.backdropScrim),
        ),

        // Póster + título, alineados abajo.
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 96,
                  height: 144,
                  child: PosterImage(
                    imagePath: item.posterPath,
                    title: item.displayTitle,
                    seed: item.id,
                    size: 'w185',
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    MediaTypeTag(isTv: item.type.isTv),
                    const SizedBox(height: 8),
                    Text(
                      item.displayTitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                        height: 1.15,
                      ),
                    ),
                    if (details.hasTagline) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        details.tagline!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.pal.textSecondary,
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  Bloque de título: puntuación y metadatos
// ══════════════════════════════════════════════════════════════════════════

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.details, required this.entry});

  final MediaDetails details;
  final WatchlistItem? entry;

  @override
  Widget build(BuildContext context) {
    final MediaItem item = details.item;
    final bool isTv = item.type.isTv;

    final List<String> meta = <String>[
      if (item.year != null) '${item.year}',
      if (!isTv && details.runtime != null) Formatters.runtime(details.runtime),
      if (isTv && details.episodeRuntimes.isNotEmpty)
        Formatters.episodeRuntime(details.episodeRuntimes),
      if (isTv && details.numberOfSeasons != null)
        '${details.numberOfSeasons} temp.',
      if (isTv && details.numberOfEpisodes != null)
        '${details.numberOfEpisodes} ${details.numberOfEpisodes == 1 ? 'episodio' : 'episodios'}',
      if (item.originalLanguage != null)
        Formatters.languageName(item.originalLanguage),
      if (details.status != null) _StatusLabel.map(details.status!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            if (item.hasVote)
              RatingBadge(
                voteAverage: item.voteAverage,
                size: RatingBadgeSize.large,
              ),
            if (item.voteCount > 0)
              Text(
                '${Formatters.voteCount(item.voteCount)} votos',
                style: context.text.bodySmall,
              ),
          ],
        ),
        if (meta.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            Formatters.join(meta),
            style: context.text.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.pal.textSecondary,
            ),
          ),
        ],
        if (details.genreNames.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: details.genreNames
                .map(
                  (String name) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: context.pal.surfaceHigh,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: context.pal.outline),
                    ),
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: context.pal.textSecondary,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
        if (entry != null) ...<Widget>[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.crimson.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.crimson.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.bookmark_rounded,
                  size: 15,
                  color: AppColors.crimson,
                ),
                const SizedBox(width: 8),
                Text(
                  'En Mi lista · ${entry!.status.label}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.crimsonLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Traduce los estados técnicos de TMDB a texto legible.
abstract final class _StatusLabel {
  static String map(String status) => switch (status.toLowerCase()) {
    'released' => 'Estrenada',
    'returning series' => 'En emisión',
    'in production' => 'En producción',
    'planned' => 'Anunciada',
    'post production' => 'En postproducción',
    'canceled' => 'Cancelada',
    'ended' => 'Finalizada',
    'pilot' => 'Piloto',
    'rumored' => 'Rumoreada',
    _ => status,
  };
}

// ══════════════════════════════════════════════════════════════════════════
//  Acciones
// ══════════════════════════════════════════════════════════════════════════

class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.details, required this.mediaId});

  final MediaDetails details;
  final MediaId mediaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MediaVideo? trailer = details.trailer;
    final WatchlistItem? entry = ref.watch(watchlistEntryProvider(mediaId));

    return Row(
      children: <Widget>[
        if (trailer != null)
          Expanded(
            flex: 3,
            child: FilledButton.icon(
              onPressed: () => _openTrailer(context, trailer),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
              icon: const Icon(Icons.play_arrow_rounded, size: 24),
              label: const Text('Tráiler'),
            ),
          )
        else
          Expanded(
            flex: 3,
            child: OutlinedButton.icon(
              onPressed: null,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
              icon: const Icon(Icons.play_disabled_rounded, size: 22),
              label: const Text('Sin tráiler'),
            ),
          ),

        const SizedBox(width: 10),

        WatchlistToggle.labeled(mediaId: mediaId, media: details.item),

        const SizedBox(width: 10),

        // Reproductor integrado. Mientras el negocio no aporte sus propias
        // fuentes autorizadas (fase 2), se abre con la pieza de muestra CC:
        // el reproductor, los controles y la ruta ya quedan reales.
        FilledButton.icon(
          onPressed: () => context.push(
            '/player',
            extra: PlayerArgs.sample(details.displayTitle),
          ),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Reproducir'),
        ),
        const SizedBox(width: 10),

        // Control de progreso: solo si el título ya está guardado, porque sin
        // entrada en la lista no hay dónde registrar el porcentaje.
        if (entry != null)
          _ProgressButton(
            percent: entry.progressPercent ?? 0,
            onChanged: (int value) => ref
                .read(watchlistControllerProvider.notifier)
                .setProgress(entry.key, value),
          ),
      ],
    );
  }

  Future<void> _openTrailer(BuildContext context, MediaVideo trailer) async {
    final Uri uri = Uri.parse(trailer.watchUrl);
    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        _showFallback(context, trailer);
      }
    } catch (_) {
      // En web o en plataformas sin app externa, `launchUrl` puede lanzar:
      // se ofrece el enlace para copiarlo en vez de mostrar un error opaco.
      if (context.mounted) _showFallback(context, trailer);
    }
  }

  void _showFallback(BuildContext context, MediaVideo trailer) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'No se pudo abrir el reproductor',
                style: sheetContext.text.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Copia este enlace para verlo en tu navegador:',
                style: sheetContext.text.bodySmall,
              ),
              const SizedBox(height: 12),
              SelectableText(
                trailer.watchUrl,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.gold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón compacto para marcar el progreso de visionado.
class _ProgressButton extends StatelessWidget {
  const _ProgressButton({required this.percent, required this.onChanged});

  final int percent;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Marcar progreso',
      position: PopupMenuPosition.under,
      color: context.pal.surfaceHighest,
      onSelected: onChanged,
      itemBuilder: (BuildContext context) => const <PopupMenuItem<int>>[
        PopupMenuItem<int>(value: 0, child: _ProgressOption('Sin empezar')),
        PopupMenuItem<int>(value: 25, child: _ProgressOption('25 %')),
        PopupMenuItem<int>(value: 50, child: _ProgressOption('50 %')),
        PopupMenuItem<int>(value: 75, child: _ProgressOption('75 %')),
        PopupMenuItem<int>(value: 100, child: _ProgressOption('Terminado')),
      ],
      child: Container(
        width: 50,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.pal.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.pal.outline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              percent >= 100
                  ? Icons.check_circle_rounded
                  : Icons.pie_chart_outline_rounded,
              size: 17,
              color: percent >= 100
                  ? AppColors.success
                  : context.pal.textSecondary,
            ),
            const SizedBox(height: 1),
            Text(
              '$percent%',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: percent >= 100
                    ? AppColors.success
                    : context.pal.textDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressOption extends StatelessWidget {
  const _ProgressOption(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(Icons.circle_outlined, size: 15, color: context.pal.textSecondary),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13.5)),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  Ficha técnica
// ══════════════════════════════════════════════════════════════════════════

class _FactsGrid extends StatelessWidget {
  const _FactsGrid({required this.details});

  final MediaDetails details;

  @override
  Widget build(BuildContext context) {
    final List<({IconData icon, String label, String value})> facts =
        <({IconData icon, String label, String value})>[
          if (details.directors.isNotEmpty)
            (
              icon: Icons.movie_creation_outlined,
              label: details.directors.length == 1
                  ? 'Dirección'
                  : 'Direcciones',
              value: details.directors.join(', '),
            ),
          if (details.createdBy.isNotEmpty)
            (
              icon: Icons.create_outlined,
              label: 'Creada por',
              value: details.createdBy.join(', '),
            ),
          if (details.productionCountries.isNotEmpty)
            (
              icon: Icons.public_rounded,
              label: 'País',
              value: details.productionCountries.join(', '),
            ),
          if (details.spokenLanguages.isNotEmpty)
            (
              icon: Icons.translate_rounded,
              label: 'Idiomas',
              value: details.spokenLanguages.take(3).join(', '),
            ),
          if (details.lastAirDate != null)
            (
              icon: Icons.event_rounded,
              label: 'Última emisión',
              value: Formatters.shortDate(details.lastAirDate),
            ),
          if (details.inProduction == true)
            (
              icon: Icons.construction_rounded,
              label: 'Producción',
              value: 'En curso',
            ),
          if (details.budget != null && details.budget! > 0)
            (
              icon: Icons.payments_outlined,
              label: 'Presupuesto',
              value: _money(details.budget!),
            ),
          if (details.revenue != null && details.revenue! > 0)
            (
              icon: Icons.trending_up_rounded,
              label: 'Recaudación',
              value: _money(details.revenue!),
            ),
          if (details.nextEpisodeToAir != null)
            (
              icon: Icons.schedule_rounded,
              label: 'Próximo episodio',
              value: details.nextEpisodeToAir!.shortCode,
            ),
        ];

    if (facts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: 'Ficha técnica',
          padding: EdgeInsets.only(bottom: 10),
        ),
        for (final ({IconData icon, String label, String value}) fact in facts)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(fact.icon, size: 17, color: context.pal.textDisabled),
                const SizedBox(width: 11),
                SizedBox(
                  width: 108,
                  child: Text(
                    fact.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: context.pal.textDisabled,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    fact.value,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: context.pal.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (details.homepage != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: TextButton.icon(
              onPressed: () => _openUrl(details.homepage!),
              icon: const Icon(Icons.link_rounded, size: 17),
              label: const Text('Sitio oficial'),
            ),
          ),
      ],
    );
  }

  static String _money(int amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)} mil M \$';
    }
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)} M \$';
    }
    return '\$ $amount';
  }

  static Future<void> _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Enlace no abrible en esta plataforma: se ignora sin bloquear la UI.
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  Temporadas y episodios
// ══════════════════════════════════════════════════════════════════════════

class _SeasonsBlock extends StatelessWidget {
  const _SeasonsBlock({
    required this.seriesId,
    required this.seasons,
    this.totalEpisodes,
  });

  final int seriesId;
  final List<Season> seasons;
  final int? totalEpisodes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Temporadas',
          subtitle: totalEpisodes == null
              ? '${seasons.length} temporadas'
              : '${seasons.length} temporadas · $totalEpisodes episodios',
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 6),
        ),
        for (final Season season in seasons)
          _SeasonTile(seriesId: seriesId, season: season),
      ],
    );
  }
}

class _SeasonTile extends ConsumerWidget {
  const _SeasonTile({required this.seriesId, required this.season});

  final int seriesId;
  final Season season;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Theme(
      // Se quita el divisor superior que ExpansionTile pinta por defecto: con
      // varias temporadas seguidas se veía una doble línea.
      data: context.theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.only(bottom: 10),
        iconColor: AppColors.crimson,
        collapsedIconColor: context.pal.textDisabled,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            width: 40,
            height: 60,
            child: PosterImage(
              imagePath: season.posterPath,
              title: season.name,
              seed: season.id,
              size: 'w92',
            ),
          ),
        ),
        title: Text(
          season.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            Formatters.join(<String?>[
              if (season.hasEpisodes) '${season.episodeCount} ep.',
              if (season.airDate != null) Formatters.year(season.airDate),
            ]),
            style: TextStyle(fontSize: 11.5, color: context.pal.textDisabled),
          ),
        ),
        // Los episodios se piden solo al desplegar la temporada, no de golpe.
        children: <Widget>[
          _EpisodeList(seriesId: seriesId, seasonNumber: season.number),
        ],
      ),
    );
  }
}

class _EpisodeList extends ConsumerWidget {
  const _EpisodeList({required this.seriesId, required this.seasonNumber});

  final int seriesId;
  final int seasonNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Episode>> episodes = ref.watch(
      seasonEpisodesProvider((seriesId: seriesId, season: seasonNumber)),
    );

    return episodes.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (Object error, StackTrace st) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: AppErrorView(
          compact: true,
          error: error,
          onRetry: () => ref.invalidate(
            seasonEpisodesProvider((seriesId: seriesId, season: seasonNumber)),
          ),
        ),
      ),
      data: (List<Episode> list) {
        if (list.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Todavía no hay episodios publicados para esta temporada.',
              style: TextStyle(fontSize: 12.5, color: context.pal.textDisabled),
            ),
          );
        }
        return Column(
          children: list
              .map((Episode episode) => _EpisodeTile(episode: episode))
              .toList(growable: false),
        );
      },
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({required this.episode});

  final Episode episode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.pal.surfaceHigh,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '${episode.number}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: context.pal.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  episode.name.isEmpty ? episode.shortCode : episode.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  Formatters.join(<String?>[
                    if (episode.airDate != null)
                      Formatters.shortDate(episode.airDate),
                    if (episode.runtime != null) '${episode.runtime} min',
                    if (episode.voteAverage > 0)
                      '★ ${Formatters.vote(episode.voteAverage)}',
                  ]),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.pal.textDisabled,
                  ),
                ),
                if (episode.overview.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 5),
                  Text(
                    episode.overview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.45,
                      color: context.pal.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  Estados de carga y error
// ══════════════════════════════════════════════════════════════════════════

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        ShimmerBox(height: 300, borderRadius: 0),
        Padding(
          padding: EdgeInsets.all(context.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              ShimmerBox(height: 22, width: 210),
              SizedBox(height: 12),
              ShimmerBox(height: 13, width: 150),
              SizedBox(height: 24),
              ShimmerBox(height: 50, borderRadius: 14),
              SizedBox(height: 22),
              ShimmerBox(height: 64),
              SizedBox(height: 8),
              ShimmerBox(height: 64),
              SizedBox(height: 8),
              ShimmerBox(height: 64),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailError extends ConsumerWidget {
  const _DetailError({required this.error, required this.mediaId});

  final Object error;
  final MediaId mediaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isConfig =
        error is UnauthorizedException ||
        (error is AppException &&
            (error as AppException).isConfigurationProblem);

    return Scaffold(
      appBar: AppBar(),
      body: AppErrorView(
        error: error,
        title: isConfig ? 'Falta configurar TMDB' : null,
        onRetry: () => ref.invalidate(mediaDetailsProvider(mediaId)),
      ),
    );
  }
}
