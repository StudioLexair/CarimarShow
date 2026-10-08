import 'package:equatable/equatable.dart';

import 'media_type.dart';

/// Referencia mínima e inequívoca a un título: tipo + identificador de TMDB.
///
/// Hace falta porque TMDB numera películas y series en secuencias **independientes**:
/// el `id` 155 es a la vez una película y una serie distintas. Cualquier map,
/// clave de caché o fila de base de datos necesita el par completo.
///
/// Se usa como clave de `family` en los proveedores, así que implementa
/// igualdad por valor.
class MediaId extends Equatable {
  const MediaId(this.type, this.id);

  /// Construye a partir de la forma canónica `"movie:155"`.
  ///
  /// Devuelve `null` si la cadena no tiene ese formato, en lugar de lanzar: se
  /// usa al leer claves persistidas que podrían venir de versiones anteriores.
  static MediaId? tryParse(String key) {
    final int separator = key.indexOf(':');
    if (separator <= 0 || separator == key.length - 1) return null;
    final MediaType? type = MediaType.tryParse(key.substring(0, separator));
    final int? id = int.tryParse(key.substring(separator + 1));
    if (type == null || id == null || type.isPerson) return null;
    return MediaId(type, id);
  }

  /// Igual que [tryParse] pero lanza si la clave es inválida.
  static MediaId parse(String key) {
    final MediaId? parsed = tryParse(key);
    if (parsed == null) {
      throw FormatException('Clave de título inválida', key);
    }
    return parsed;
  }

  final MediaType type;
  final int id;

  /// Forma canónica: `"movie:155"`.
  String get key => '${type.apiValue}:$id';

  /// Ruta de la ficha dentro de la app, p. ej. `/title/movie/155`.
  String get route => '/title/${type.apiValue}/$id';

  @override
  String toString() => 'MediaId($key)';

  @override
  List<Object?> get props => <Object?>[type, id];
}
