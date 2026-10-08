import '../constants/app_strings.dart';

/// Resultado de validar un campo de formulario.
typedef Validator = String? Function(String? value);

/// Validadores reutilizables para los formularios de autenticación.
abstract final class Validators {
  Validators._();

  /// Expresión pragmática: suficiente para formularios sin rechazar dominios raros.
  static final RegExp _emailPattern = RegExp(
    r'^[\w.!#$%&’*+/=?^`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?'
    r'(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
  );

  static Validator required(String? message) =>
      (String? value) => (value == null || value.trim().isEmpty)
      ? (message ?? Strings.fieldRequired)
      : null;

  static Validator email() => (String? value) {
    final String? v = value?.trim();
    if (v == null || v.isEmpty) return Strings.fieldRequired;
    return _emailPattern.hasMatch(v) ? null : Strings.invalidEmail;
  };

  /// Contraseña: mínimo 8 caracteres y al menos un número.
  static Validator password({int minLength = 8}) => (String? value) {
    final String v = value ?? '';
    if (v.isEmpty) return Strings.fieldRequired;
    if (v.length < minLength) return Strings.passwordTooShort;
    if (!v.contains(RegExp(r'\d'))) return Strings.passwordNeedsNumber;
    return null;
  };

  static Validator minLength(int length, [String? message]) => (String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return Strings.fieldRequired;
    return v.length < length ? (message ?? 'Mínimo $length caracteres') : null;
  };

  /// Compone validadores; devuelve el primer error encontrado.
  static Validator compose(List<Validator> validators) => (String? value) {
    for (final Validator validator in validators) {
      final String? error = validator(value);
      if (error != null) return error;
    }
    return null;
  };
}
