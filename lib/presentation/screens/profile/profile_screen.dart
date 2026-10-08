import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../domain/entities/app_user.dart';
import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/watchlist_providers.dart';
import '../../widgets/brand_app_bar.dart';

/// Perfil y ajustes.
///
/// Reúne en una pantalla lo que el usuario necesita saber sobre sus datos:
/// dónde se guardan (dispositivo o nube), qué hay guardado y cómo se ve la app.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(currentUserProvider);
    final WatchlistStats stats = ref.watch(watchlistStatsProvider);
    final bool synced = ref.watch(watchlistIsSyncedProvider);
    final bool accountsEnabled = ref.watch(accountsEnabledProvider);
    final bool isDemoCatalog = ref.watch(demoModeProvider);
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    final bool adultContent = ref.watch(adultContentProvider);

    return Scaffold(
      appBar: const BrandAppBar(showSearch: false),
      body: ListView(
        padding: EdgeInsets.fromLTRB(context.gutter, 8, context.gutter, 40),
        children: <Widget>[
          _ProfileHeader(user: user),
          const SizedBox(height: 24),

          _StatsRow(stats: stats),
          const SizedBox(height: 26),

          const _SectionLabel('Apariencia'),
          _ThemeModeSelector(current: themeMode),
          const SizedBox(height: 12),

          const _SectionLabel('Contenido'),
          _SwitchTile(
            icon: Icons.eighteen_mp_outlined,
            title: 'Mostrar contenido para adultos',
            subtitle: 'Incluye títulos +18 en los listados y en la búsqueda.',
            value: adultContent,
            onChanged: (bool value) =>
                ref.read(adultContentProvider.notifier).set(value),
          ),
          const SizedBox(height: 12),

          const _SectionLabel('Portada'),
          _SwitchTile(
            icon: Icons.campaign_outlined,
            title: 'Banner promocional',
            subtitle: 'Muestra el aviso editable en la portada.',
            value: ref.watch(promoSettingsProvider).enabled,
            onChanged: (bool v) =>
                ref.read(promoSettingsProvider.notifier).setEnabled(v),
          ),
          const SizedBox(height: 12),

          const _SectionLabel('Almacenamiento'),
          _InfoTile(
            icon: Icons.sd_storage_outlined,
            title: 'Caché del catálogo',
            value: _fmtBytes(ref.watch(cacheSizeProvider)),
            subtitle:
                'Copias locales de lo consultado para navegar sin conexión.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final int freed = await ref.read(catalogCacheProvider).clear();
                ref.invalidate(cacheSizeProvider);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Caché vaciada: ${_fmtBytes(freed)} liberados',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.cleaning_services_outlined, size: 18),
              label: const Text('Liberar espacio'),
            ),
          ),
          const SizedBox(height: 12),

          const _SectionLabel('Negocio'),
          Card(
            color: context.pal.surface,
            child: ListTile(
              leading: const Icon(
                Icons.storefront_outlined,
                color: AppColors.accent,
              ),
              title: const Text('Datos del negocio'),
              subtitle: const Text(
                'Dirección, horario y contacto de CarimarShow.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/negocio'),
            ),
          ),
          const SizedBox(height: 12),

          const _SectionLabel('Tus datos'),
          _InfoTile(
            icon: Icons.cloud_outlined,
            title: 'Sincronización',
            value: synced
                ? 'En la nube (Supabase)'
                : 'Solo en este dispositivo',
            subtitle: synced
                ? 'Mi lista se actualiza en todos tus dispositivos.'
                : 'Configura Supabase para llevar tu lista a cualquier equipo.',
          ),
          _InfoTile(
            icon: Icons.movie_outlined,
            title: 'Catálogo',
            value: isDemoCatalog ? 'Demo local' : 'TMDB en directo',
            subtitle: isDemoCatalog
                ? 'Títulos ficticios incluidos en la app.'
                : 'Datos reales de The Movie Database.',
          ),
          _InfoTile(
            icon: Icons.language_outlined,
            title: 'Idioma del catálogo',
            value: ref.watch(catalogLanguageProvider),
            subtitle: 'Se cambia con --dart-define=TMDB_LANGUAGE=...',
          ),
          const SizedBox(height: 12),

          const _SectionLabel('Cuenta'),
          if (accountsEnabled && user != null && !user.isGuest)
            _ActionTile(
              icon: Icons.lock_reset_rounded,
              title: 'Cambiar contraseña',
              subtitle: 'Te enviaremos un enlace a ${user.email}',
              onTap: () => _sendReset(context, ref, user.email),
            ),
          _ActionTile(
            icon: Icons.logout_rounded,
            title: Strings.logout,
            subtitle: user?.isGuest ?? false
                ? 'Cerrar la sesión local de este dispositivo'
                : 'Tendrás que volver a identificarte',
            destructive: true,
            onTap: () => _confirmLogout(context, ref),
          ),
          const SizedBox(height: 24),

          const _AboutBox(),
        ],
      ),
    );
  }

  Future<void> _sendReset(
    BuildContext context,
    WidgetRef ref,
    String email,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool sent = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(email);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Enlace enviado a $email'
              : ref.read(authControllerProvider).error ?? 'No se pudo enviar',
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text(Strings.logout),
        content: const Text(
          'Se cerrará la sesión en este dispositivo. Tu lista guardada en la '
          'nube no se borra.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
      // El router detecta la sesión cerrada y redirige solo a /login.
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  Piezas
// ══════════════════════════════════════════════════════════════════════════

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Stack(
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    AppColors.crimsonLight,
                    AppColors.crimsonDark,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                user?.initials ?? '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (user?.isGuest ?? false)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.pal.surfaceHighest,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: context.pal.outline),
                  ),
                  child: const Text(
                    'INVITADO',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: AppColors.gold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                user?.displayName ?? 'Sin sesión',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.headlineSmall,
              ),
              if (user?.email.isNotEmpty ?? false) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  user!.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall,
                ),
              ],
              if (user?.createdAt != null) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  'Miembro desde ${Formatters.shortDate(user!.createdAt)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.pal.textDisabled,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final WatchlistStats stats;

  @override
  Widget build(BuildContext context) {
    final List<({String label, String value})> cells =
        <({String label, String value})>[
          (label: 'Guardados', value: '${stats.total}'),
          (label: 'Viendo', value: '${stats.watching}'),
          (label: 'Completados', value: '${stats.completed}'),
          (label: 'Pendientes', value: '${stats.planned}'),
        ];

    return Row(
      children: <Widget>[
        for (int i = 0; i < cells.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: context.pal.surfaceHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: context.pal.outline.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                children: <Widget>[
                  Text(
                    cells[i].value,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      color: context.pal.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cells[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: context.pal.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: context.pal.textDisabled,
        ),
      ),
    );
  }
}

class _ThemeModeSelector extends ConsumerWidget {
  const _ThemeModeSelector({required this.current});

  final ThemeMode current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const List<(ThemeMode, String, IconData)> options =
        <(ThemeMode, String, IconData)>[
          (ThemeMode.system, 'Sistema', Icons.brightness_auto_rounded),
          (ThemeMode.light, 'Claro', Icons.light_mode_rounded),
          (ThemeMode.dark, 'Oscuro', Icons.dark_mode_rounded),
        ];

    return Row(
      children: <Widget>[
        for (int i = 0; i < options.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _SelectableCard(
              label: options[i].$2,
              icon: options[i].$3,
              selected: current == options[i].$1,
              onTap: () =>
                  ref.read(themeModeProvider.notifier).set(options[i].$1),
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.crimson.withValues(alpha: 0.14)
          : context.pal.surfaceHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.crimson
                  : context.pal.outline.withValues(alpha: 0.6),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            children: <Widget>[
              Icon(
                icon,
                size: 20,
                color: selected ? AppColors.crimson : context.pal.textSecondary,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppColors.crimson
                      : context.pal.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.pal.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.pal.outline.withValues(alpha: 0.6)),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.crimson,
        secondary: Icon(icon, size: 22, color: context.pal.textSecondary),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subtitle,
            style: const TextStyle(fontSize: 11.5, height: 1.4),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: context.pal.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.pal.outline.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 21, color: context.pal.textSecondary),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: context.pal.textDisabled,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final Color color = destructive
        ? AppColors.danger
        : context.pal.textPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.pal.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.pal.outline.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: onTap,
          leading: Icon(
            icon,
            size: 21,
            color: destructive ? color : context.pal.textSecondary,
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 11.5, height: 1.4),
                ),
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        ),
      ),
    );
  }
}

class _AboutBox extends StatelessWidget {
  const _AboutBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.pal.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.pal.outline.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.crimson,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Text(
                  'S',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              const Text(
                Strings.appName,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Text(
                'v0.1.0',
                style: TextStyle(
                  fontSize: 11.5,
                  color: context.pal.textDisabled,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            Strings.tmdbAttribution,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: context.pal.textDisabled,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Aplicación de demostración. No reproduce ni aloja contenido: solo '
            'muestra información pública de catálogos.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: context.pal.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

/// Formatea bytes como KB/MB para la sección de almacenamiento.
String _fmtBytes(int bytes) {
  if (bytes <= 0) return '0 KB';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
