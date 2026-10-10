import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/business_info.dart';
import '../../../core/theme/app_colors.dart';

/// Pantalla con los datos del negocio real.
///
/// Es la «etapa informativa» que describió el cliente: que la gente sepa qué
/// hay, dónde recogerlo y a qué hora. Los teléfonos y el correo abren el
/// marcador o el cliente de correo; la dirección abre el mapa.
class BusinessInfoScreen extends StatelessWidget {
  const BusinessInfoScreen({super.key});

  Future<void> _open(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pal.background,
      appBar: AppBar(
        title: const Text(BusinessInfo.name),
        backgroundColor: context.pal.background,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset('assets/brand/logo.jpeg'),
          ),
          const SizedBox(height: 22),
          _Row(
            icon: Icons.storefront_outlined,
            title: 'Dirección',
            body: BusinessInfo.address,
            onTap: () => _open(BusinessInfo.mapsUrl),
            actionLabel: 'Ver en el mapa',
          ),
          _Row(
            icon: Icons.schedule_outlined,
            title: 'Horario',
            body: BusinessInfo.schedule,
          ),
          for (final String phone in BusinessInfo.phones)
            _Row(
              icon: Icons.phone_outlined,
              title: 'Teléfono',
              body: phone,
              onTap: () => _open('tel:+53$phone'),
              actionLabel: 'Llamar',
            ),
          _Row(
            icon: Icons.alternate_email_rounded,
            title: 'Correo',
            body: BusinessInfo.email,
            onTap: () => _open('mailto:${BusinessInfo.email}'),
            actionLabel: 'Escribir',
          ),
          const SizedBox(height: 18),
          Text(
            'CarimarShow es un producto de Studio Lexair, creado y '
            'desarrollado por Airien Yolexis Rojas Roque. El contenido '
            'audiovisual se reproduce solo desde fuentes autorizadas por el '
            'titular de los derechos. Consulta al desarrollador: '
            'studio.lexair@gmail.com · +53 52678747.',
            style: TextStyle(
              color: context.pal.textDisabled,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.body,
    this.onTap,
    this.actionLabel,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: context.pal.surface,
      child: ListTile(
        leading: Icon(icon, color: AppColors.accent),
        title: Text(
          title,
          style: TextStyle(fontSize: 13, color: context.pal.textDisabled),
        ),
        subtitle: Text(
          body,
          style: TextStyle(fontSize: 15, color: context.pal.textPrimary),
        ),
        trailing: onTap == null
            ? null
            : Text(
                actionLabel ?? 'Abrir',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
        onTap: onTap,
      ),
    );
  }
}
