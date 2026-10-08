/// Datos del negocio real para el que se construye la aplicación.
///
/// Los dio el cliente por WhatsApp junto con el logotipo. Se muestran en la
/// pantalla «El negocio» y se añaden al pie de los mensajes compartidos, que
/// es justo el uso que él describió: que la lista compartida lleve debajo
/// dónde y cuándo recoger el pedido.
abstract final class BusinessInfo {
  static const String name = 'CarimarShow';
  static const String address =
      'Lealtad 559, entre Salud y Dragones, Centro Habana';
  static const String schedule = 'Lunes a viernes, 1:00 PM – 10:00 PM';
  static const List<String> phones = <String>['53324928', '78660658'];
  static const String email = 'carimarshowapk@qmail.com';

  static final String mapsUrl = Uri.encodeFull(
    'https://www.google.com/maps/search/?api=1&query=$address, La Habana',
  );

  /// Pie que se añade a la lista compartida.
  static final String shareFooter =
      '$name — $address · $schedule · ${phones[0]} / ${phones[1]}';
}
