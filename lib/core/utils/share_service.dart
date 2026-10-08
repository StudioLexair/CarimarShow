import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Comparte texto por el mecanismo nativo de cada plataforma.
///
/// Devuelve `true` si se abrió el share-sheet del sistema. Si la plataforma
/// no lo soporta (o el usuario lo cancela sin copiar), se deja el texto en el
/// portapapeles y se devuelve `false` para que la UI diga «copiado: pégalo
/// en WhatsApp», que es exactamente el flujo que describió el cliente: el
/// vendedor le manda la selección al dueño por chat.
abstract final class ShareService {
  static Future<bool> share(String text) async {
    try {
      await Share.share(text);
      return true;
    } catch (_) {
      try {
        await Clipboard.setData(ClipboardData(text: text));
        return false;
      } catch (_) {
        return false;
      }
    }
  }
}
