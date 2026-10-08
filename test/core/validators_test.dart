import 'package:flutter_test/flutter_test.dart';
import 'package:sinflix/core/utils/validators.dart';

void main() {
  group('Validators.email', () {
    final String? Function(String?) validate = Validators.email();

    test('acepta correos normales', () {
      expect(validate('persona@correo.com'), isNull);
      expect(validate('  persona@correo.co.uk  '), isNull);
      expect(validate('a.b+c@dominio.es'), isNull);
    });

    test('rechaza lo que no es un correo', () {
      expect(validate('sin-arroba'), isNotNull);
      expect(validate('persona@'), isNotNull);
      expect(validate('@dominio.com'), isNotNull);
      expect(validate('persona@dominio'), isNotNull);
    });

    test('pide el campo cuando viene vacío', () {
      expect(validate(''), isNotNull);
      expect(validate(null), isNotNull);
    });
  });

  group('Validators.password', () {
    final String? Function(String?) validate = Validators.password();

    test('acepta 8+ caracteres con algún número', () {
      expect(validate('clave123'), isNull);
      expect(validate('una-clave-larga-1'), isNull);
    });

    test('rechaza contraseñas cortas', () {
      expect(validate('ab1'), isNotNull);
    });

    test('exige al menos un número', () {
      expect(validate('sololetras'), isNotNull);
    });

    test('no acepta vacío', () {
      expect(validate(''), isNotNull);
      expect(validate(null), isNotNull);
    });

    test('respeta el mínimo personalizado', () {
      final String? Function(String?) strict = Validators.password(
        minLength: 12,
      );
      expect(strict('clave123'), isNotNull);
      expect(strict('clave-larga-12'), isNull);
    });
  });

  group('Validators.compose', () {
    test('devuelve el primer error y se detiene', () {
      final String? Function(String?) validate =
          Validators.compose(<String? Function(String?)>[
            Validators.required('obligatorio'),
            Validators.minLength(5, 'demasiado corto'),
          ]);
      expect(validate(''), 'obligatorio');
      expect(validate('abc'), 'demasiado corto');
      expect(validate('abcde'), isNull);
    });
  });

  group('Validators.minLength', () {
    test('recorta espacios antes de medir', () {
      final String? Function(String?) validate = Validators.minLength(4);
      expect(validate('   ab   '), isNotNull);
      expect(validate('abcd'), isNull);
    });
  });
}
