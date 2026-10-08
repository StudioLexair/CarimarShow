import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core_providers.dart';

/// Ajustes de la portada que el dueño del negocio puede activar o desactivar.
///
/// El cliente pidió «un banner promocionante que lo puedes poner o no puedes
/// poner»: de ahí que el texto sea editable y el interruptor persista en el
/// dispositivo.
class PromoSettings extends Equatable {
  const PromoSettings({this.enabled = true, this.text = defaultText});

  static const String defaultText =
      '🎬 Haz tu pedido desde la app: guarda lo que quieres en tu lista y '
      'compártela. Te lo tenemos listo en el negocio.';

  final bool enabled;
  final String text;

  PromoSettings copyWith({bool? enabled, String? text}) =>
      PromoSettings(enabled: enabled ?? this.enabled, text: text ?? this.text);

  @override
  List<Object?> get props => <Object?>[enabled, text];
}

class PromoSettingsController extends Notifier<PromoSettings> {
  static const String _kEnabled = 'settings.promo_enabled';
  static const String _kText = 'settings.promo_text';

  @override
  PromoSettings build() {
    final SharedPreferences prefs = ref.watch(sharedPreferencesProvider);
    return PromoSettings(
      enabled: prefs.getBool(_kEnabled) ?? true,
      text: prefs.getString(_kText) ?? PromoSettings.defaultText,
    );
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    await ref.read(sharedPreferencesProvider).setBool(_kEnabled, value);
  }

  Future<void> setText(String value) async {
    state = state.copyWith(text: value);
    await ref.read(sharedPreferencesProvider).setString(_kText, value);
  }
}

final NotifierProvider<PromoSettingsController, PromoSettings>
promoSettingsProvider =
    NotifierProvider<PromoSettingsController, PromoSettings>(
      PromoSettingsController.new,
    );

/// Tamaño ocupado por la caché del catálogo, para la sección «Almacenamiento».
final Provider<int> cacheSizeProvider = Provider<int>(
  (Ref ref) => ref.watch(catalogCacheProvider).sizeBytes(),
);
