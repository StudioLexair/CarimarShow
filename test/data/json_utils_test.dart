import 'package:flutter_test/flutter_test.dart';
import 'package:carimarshow/data/mappers/json_utils.dart';

/// TMDB es inconsistente: omite campos, manda `null` donde otras APIs mandarían
/// cadena vacía y mezcla tipos. Estos tests fijan el comportamiento tolerante
/// que evita que un dato raro tumbe un listado entero.
void main() {
  group('Json.strOrNull', () {
    test('trata la cadena vacía como ausencia', () {
      expect(Json.strOrNull(<String, dynamic>{'a': ''}, 'a'), isNull);
      expect(Json.strOrNull(<String, dynamic>{'a': '   '}, 'a'), isNull);
      expect(Json.strOrNull(<String, dynamic>{'a': ' hola '}, 'a'), 'hola');
    });

    test('no lanza con claves ausentes', () {
      expect(Json.strOrNull(<String, dynamic>{}, 'x'), isNull);
    });

    test('convierte números a texto en lugar de fallar', () {
      expect(Json.strOrNull(<String, dynamic>{'a': 42}, 'a'), '42');
    });
  });

  group('Json.str', () {
    test('usa el valor por defecto', () {
      expect(Json.str(<String, dynamic>{}, 'x', fallback: '—'), '—');
      expect(Json.str(<String, dynamic>{'x': null}, 'x', fallback: '—'), '—');
    });
  });

  group('Json.intOr / intOrNull', () {
    test('acepta num y cadenas numéricas', () {
      expect(Json.intOr(<String, dynamic>{'a': 7.9}, 'a', 0), 7);
      expect(Json.intOr(<String, dynamic>{'a': '12'}, 'a', 0), 12);
      expect(Json.intOr(<String, dynamic>{'a': 'basura'}, 'a', -1), -1);
      expect(Json.intOr(<String, dynamic>{}, 'a', 5), 5);
    });

    test('intOrNull distingue ausencia de cero', () {
      expect(Json.intOrNull(<String, dynamic>{}, 'a'), isNull);
      expect(Json.intOrNull(<String, dynamic>{'a': 0}, 'a'), 0);
    });
  });

  group('Json.doubleOr', () {
    test('enteros, decimales y cadenas', () {
      expect(Json.doubleOr(<String, dynamic>{'a': 8}, 'a', 0), 8.0);
      expect(Json.doubleOr(<String, dynamic>{'a': 8.5}, 'a', 0), 8.5);
      expect(Json.doubleOr(<String, dynamic>{'a': '6.25'}, 'a', 0), 6.25);
      expect(Json.doubleOr(<String, dynamic>{'a': null}, 'a', 1.5), 1.5);
    });
  });

  group('Json.boolOr', () {
    test('interpreta variantes habituales', () {
      expect(Json.boolOr(<String, dynamic>{'a': true}, 'a', false), isTrue);
      expect(Json.boolOr(<String, dynamic>{'a': 1}, 'a', false), isTrue);
      expect(Json.boolOr(<String, dynamic>{'a': 'true'}, 'a', false), isTrue);
      expect(Json.boolOr(<String, dynamic>{'a': 'no'}, 'a', true), isFalse);
      expect(Json.boolOr(<String, dynamic>{}, 'a', true), isTrue);
    });
  });

  group('Json.dateOrNull', () {
    test('fecha corta y marca de tiempo', () {
      expect(
        Json.dateOrNull(<String, dynamic>{'a': '2008-07-16'}, 'a'),
        DateTime(2008, 7, 16),
      );
      expect(
        Json.dateOrNull(<String, dynamic>{'a': '2008-07-16T00:00:00Z'}, 'a'),
        isNotNull,
      );
    });

    test('devuelve null ante basura', () {
      expect(Json.dateOrNull(<String, dynamic>{'a': ''}, 'a'), isNull);
      expect(Json.dateOrNull(<String, dynamic>{'a': '???'}, 'a'), isNull);
    });
  });

  group('Json.objOrEmpty / objOrNull', () {
    test('no lanza si el subobjeto falta o es de otro tipo', () {
      expect(Json.objOrEmpty(<String, dynamic>{}, 'a'), isEmpty);
      expect(Json.objOrEmpty(<String, dynamic>{'a': 'texto'}, 'a'), isEmpty);
      expect(
        Json.objOrEmpty(<String, dynamic>{
          'a': <String, dynamic>{'b': 1},
        }, 'a'),
        <String, dynamic>{'b': 1},
      );
      expect(Json.objOrNull(<String, dynamic>{}, 'a'), isNull);
    });
  });

  group('Json.list', () {
    test('filtra entradas que no son objetos', () {
      final List<Map<String, dynamic>> result = Json.list(<String, dynamic>{
        'a': <Object?>[
          <String, dynamic>{'id': 1},
          'basura',
          null,
          <String, dynamic>{'id': 2},
        ],
      }, 'a');
      expect(result, hasLength(2));
      expect(result.first['id'], 1);
    });

    test('lista vacía si la clave falta o no es lista', () {
      expect(Json.list(<String, dynamic>{}, 'a'), isEmpty);
      expect(Json.list(<String, dynamic>{'a': 5}, 'a'), isEmpty);
    });
  });

  group('Json.intList', () {
    test('mezcla de enteros, decimales y cadenas', () {
      expect(
        Json.intList(<String, dynamic>{
          'a': <Object?>[28, 12.0, '80', null, 'x'],
        }, 'a'),
        <int>[28, 12, 80],
      );
    });
  });

  group('Json.strList', () {
    test('descarta vacíos y nulos', () {
      expect(
        Json.strList(<String, dynamic>{
          'a': <Object?>['ES', '', null, ' US '],
        }, 'a'),
        <String>['ES', 'US'],
      );
    });
  });

  group('Json.mapListLenient', () {
    test('conserva los elementos válidos y descarta los que fallan', () {
      final List<int> result = Json.mapListLenient<int>(
        <Map<String, dynamic>>[
          <String, dynamic>{'n': 1},
          <String, dynamic>{'n': 'no-es-numero'},
          <String, dynamic>{'n': 3},
        ],
        (Map<String, dynamic> json) {
          final Object? raw = json['n'];
          return raw is int ? raw : null;
        },
      );
      expect(result, <int>[1, 3]);
    });
  });
}
