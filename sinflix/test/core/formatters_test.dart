import 'package:flutter_test/flutter_test.dart';
import 'package:sinflix/core/utils/formatters.dart';

void main() {
  group('Formatters.year', () {
    test('extrae el año de una fecha válida', () {
      expect(Formatters.year(DateTime(2008, 7, 16)), '2008');
    });

    test('devuelve cadena vacía si no hay fecha', () {
      expect(Formatters.year(null), '');
    });
  });

  group('Formatters.parseDate', () {
    test('acepta fecha corta de TMDB', () {
      expect(Formatters.parseDate('2008-07-16'), DateTime(2008, 7, 16));
    });

    test('acepta marca de tiempo completa', () {
      final DateTime? parsed = Formatters.parseDate('2008-07-16T12:30:00.000Z');
      expect(parsed, isNotNull);
      expect(parsed!.year, 2008);
    });

    test('devuelve null con basura', () {
      expect(Formatters.parseDate(''), isNull);
      expect(Formatters.parseDate(null), isNull);
      expect(Formatters.parseDate('no-es-fecha'), isNull);
    });
  });

  group('Formatters.vote', () {
    test('un decimal y recorte al rango 0-10', () {
      expect(Formatters.vote(8.51), '8.5');
      expect(Formatters.vote(9.99), '10.0');
      expect(Formatters.vote(14.0), '10.0');
    });

    test('cadena vacía cuando no hay votos', () {
      expect(Formatters.vote(0), '');
      expect(Formatters.vote(null), '');
      expect(Formatters.vote(-3), '');
    });
  });

  group('Formatters.votePercent', () {
    test('convierte la escala 0-10 a porcentaje redondeado', () {
      expect(Formatters.votePercent(8.5), '85%');
      expect(Formatters.votePercent(7.04), '70%');
      expect(Formatters.votePercent(0), '');
    });
  });

  group('Formatters.runtime', () {
    test('horas y minutos', () {
      expect(Formatters.runtime(152), '2 h 32 min');
      expect(Formatters.runtime(60), '1 h');
      expect(Formatters.runtime(48), '48 min');
    });

    test('guion cuando falta el dato', () {
      expect(Formatters.runtime(null), '—');
      expect(Formatters.runtime(0), '—');
    });
  });

  group('Formatters.episodeRuntime', () {
    test('rango cuando hay duraciones distintas', () {
      expect(Formatters.episodeRuntime(<int>[45, 25, 30]), '25–45 min');
    });

    test('valor único cuando todas coinciden', () {
      expect(Formatters.episodeRuntime(<int>[42, 42]), '42 min');
    });

    test('ignora ceros y null', () {
      expect(Formatters.episodeRuntime(<int>[0, 0]), '—');
      expect(Formatters.episodeRuntime(null), '—');
      expect(Formatters.episodeRuntime(<int>[]), '—');
    });
  });

  group('Formatters.join', () {
    test('descarta nulos y vacíos', () {
      expect(Formatters.join(<String?>['A', null, '', 'B']), 'A · B');
      expect(Formatters.join(<String?>[null, null]), '');
    });

    test('respeta el separador personalizado', () {
      expect(Formatters.join(<String?>['x', 'y'], separator: ', '), 'x, y');
    });
  });

  group('Formatters.voteCount', () {
    test('formato compacto y cero', () {
      expect(Formatters.voteCount(0), '');
      expect(Formatters.voteCount(null), '');
      expect(Formatters.voteCount(850), isNotEmpty);
    });
  });

  group('Formatters.ellipsis', () {
    test('no corta por debajo del límite', () {
      expect(Formatters.ellipsis('corto', 20), 'corto');
    });

    test('corta en palabra con puntos suspensivos', () {
      final String result = Formatters.ellipsis('una frase bastante larga', 14);
      expect(result.endsWith('…'), isTrue);
      expect(result.length, lessThanOrEqualTo(15));
    });
  });

  group('Formatters.languageName', () {
    test('traduce códigos conocidos', () {
      expect(Formatters.languageName('es'), 'Español');
      expect(Formatters.languageName('en'), 'Inglés');
    });

    test('deja en mayúsculas lo desconocido', () {
      expect(Formatters.languageName('xx'), 'XX');
      expect(Formatters.languageName(null), '—');
    });
  });
}
