import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/business_info.dart';
import '../../../core/network/network_probe.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/settings_providers.dart';

/// Pantalla de Ajustes, separada del perfil a propósito.
///
/// El perfil habla de *quién eres* (cuenta, lista, sincronización); los ajustes
/// hablan de *cómo se comporta la app* (tema, contenido, banner, caché, red,
//créditos). Mezclarlos hacía que «tocar el perfil» abriera medio configurador.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PromoSettings promo = ref.watch(promoSettingsProvider);
    final bool adult = ref.watch(adultContentProvider);
    final ThemeMode themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: context.pal.background,
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          const _Label('Apariencia'),
          _ThemeSelector(current: themeMode),
          const SizedBox(height: 18),

          const _Label('Contenido'),
          _Switch(
            icon: Icons.eighteen_mp_outlined,
            title: 'Mostrar contenido para adultos',
            subtitle: 'Incluye títulos +18 en listados y búsqueda.',
            value: adult,
            onChanged: (bool v) =>
                ref.read(adultContentProvider.notifier).set(v),
          ),
          const SizedBox(height: 18),

          const _Label('Portada'),
          _Switch(
            icon: Icons.campaign_outlined,
            title: 'Banner promocional',
            subtitle: 'El aviso configurable que ve el cliente en la portada.',
            value: promo.enabled,
            onChanged: (bool v) =>
                ref.read(promoSettingsProvider.notifier).setEnabled(v),
          ),
          if (promo.enabled) ...<Widget>[
            const SizedBox(height: 10),
            _PromoTextField(initial: promo.text),
          ],
          const SizedBox(height: 18),

          const _Label('Almacenamiento y red'),
          _Info(
            icon: Icons.sd_storage_outlined,
            title: 'Caché del catálogo',
            value: _fmtBytes(ref.watch(cacheSizeProvider)),
            subtitle: 'Copias locales para navegar sin conexión.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final int freed = await ref.read(catalogCacheProvider).clear();
                ref.invalidate(cacheSizeProvider);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Caché vaciada: ${_fmtBytes(freed)}')),
                );
              },
              icon: const Icon(Icons.cleaning_services_outlined, size: 18),
              label: const Text('Liberar espacio'),
            ),
          ),
          const _NetworkMeter(),
          const SizedBox(height: 18),

          const _Label('Negocio y desarrollador'),
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
          const SizedBox(height: 8),
          _Info(
            icon: Icons.code_rounded,
            title: 'Desarrollado por Studio Lexair',
            value: 'Airien Yolexis Rojas Roque',
            subtitle: 'Creador y desarrollador de CarimarShow.',
          ),
          Card(
            color: context.pal.surface,
            child: ListTile(
              leading: const Icon(
                Icons.alternate_email_rounded,
                color: AppColors.accent,
              ),
              title: const Text('studio.lexair@gmail.com'),
              subtitle: const Text('Consultas al desarrollador'),
              onTap: () => launchUrl(
                Uri.parse('mailto:studio.lexair@gmail.com'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: context.pal.surface,
            child: ListTile(
              leading: const Icon(
                Icons.phone_outlined,
                color: AppColors.accent,
              ),
              title: const Text('+53 52678747'),
              subtitle: const Text('Soporte técnico'),
              onTap: () => launchUrl(
                Uri.parse('tel:+5352678747'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _Info(
            icon: Icons.verified_outlined,
            title: 'Versión',
            value: kAppVersion,
            subtitle: '© 2026 Studio Lexair. Todos los derechos reservados.',
          ),
        ],
      ),
    );
  }
}

/// Medidor de latencia y calidad de conexión: mide de verdad contra TMDB.
class _NetworkMeter extends ConsumerStatefulWidget {
  const _NetworkMeter();

  @override
  ConsumerState<_NetworkMeter> createState() => _NetworkMeterState();
}

class _NetworkMeterState extends ConsumerState<_NetworkMeter> {
  NetTier? _tier;
  int _rtt = 0;
  bool _midiendo = false;

  @override
  void initState() {
    super.initState();
    _medir();
  }

  Future<void> _medir() async {
    setState(() => _midiendo = true);
    final (NetTier tier, int rtt) = await NetworkProbe.measure();
    if (mounted)
      setState(() {
        _tier = tier;
        _rtt = rtt;
        _midiendo = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    final String estado = switch (_tier) {
      null => 'Midiendo…',
      NetTier.offline => 'Sin conexión: se servirá la caché',
      NetTier.slow => 'Conexión lenta: imágenes ligeras',
      NetTier.good => 'Conexión buena',
    };
    return Card(
      color: context.pal.surface,
      child: ListTile(
        leading: _midiendo
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Icon(
                _tier == NetTier.offline
                    ? Icons.wifi_off_rounded
                    : (_tier == NetTier.slow
                          ? Icons.network_check_rounded
                          : Icons.wifi_rounded),
                color: _tier == NetTier.good
                    ? AppColors.success
                    : (_tier == NetTier.slow
                          ? AppColors.warning
                          : AppColors.danger),
              ),
        title: const Text('Diagnóstico de red'),
        subtitle: Text(
          _tier == null ? estado : '$estado · ${_rtt < 0 ? '—' : '$_rtt ms'}',
        ),
        trailing: TextButton(
          onPressed: _midiendo ? null : _medir,
          child: const Text('Medir'),
        ),
        onTap: _midiendo ? null : _medir,
      ),
    );
  }
}

class _ThemeSelector extends ConsumerWidget {
  const _ThemeSelector({required this.current});

  final ThemeMode current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: <Widget>[
        for (final (ThemeMode mode, String label, IconData icon)
            in <(ThemeMode, String, IconData)>[
              (ThemeMode.system, 'Sistema', Icons.brightness_auto_rounded),
              (ThemeMode.light, 'Claro', Icons.light_mode_rounded),
              (ThemeMode.dark, 'Oscuro', Icons.dark_mode_rounded),
            ])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _Option(
                label: label,
                icon: icon,
                selected: current == mode,
                onTap: () => ref.read(themeModeProvider.notifier).set(mode),
              ),
            ),
          ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
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
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.16)
              : context.pal.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.accent
                : context.pal.outline.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          children: <Widget>[
            Icon(
              icon,
              size: 20,
              color: selected ? AppColors.accent : context.pal.textSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.accent : context.pal.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoTextField extends ConsumerStatefulWidget {
  const _PromoTextField({required this.initial});

  final String initial;

  @override
  ConsumerState<_PromoTextField> createState() => _PromoTextFieldState();
}

class _PromoTextFieldState extends ConsumerState<_PromoTextField> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      maxLines: 2,
      onSubmitted: (String v) =>
          ref.read(promoSettingsProvider.notifier).setText(v),
      decoration: InputDecoration(
        labelText: 'Texto del banner',
        suffixIcon: IconButton(
          tooltip: 'Guardar',
          icon: const Icon(Icons.check_rounded),
          onPressed: () =>
              ref.read(promoSettingsProvider.notifier).setText(_c.text),
        ),
      ),
    );
  }
}

class _Switch extends ConsumerWidget {
  const _Switch({
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
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: context.pal.surface,
      child: SwitchListTile(
        secondary: Icon(icon, color: AppColors.accent),
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({
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
    return Card(
      color: context.pal.surface,
      child: ListTile(
        leading: Icon(icon, color: AppColors.accent),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: Text(
          value,
          style: const TextStyle(
            color: AppColors.gold,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: context.pal.textDisabled,
        ),
      ),
    );
  }
}

String _fmtBytes(int bytes) {
  if (bytes <= 0) return '0 KB';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
