import 'package:flutter_test/flutter_test.dart';
import 'package:sinflix/core/constants/tmdb_constants.dart';
import 'package:sinflix/core/utils/tmdb_images.dart';
import 'package:sinflix/domain/entities/media_type.dart';
import 'package:sinflix/domain/entities/media_video.dart';

void main() {
  group('MediaType', () {
    test('parsea los valores de la API', () {
      expect(MediaType.tryParse('movie'), MediaType.movie);
      expect(MediaType.tryParse('tv'), MediaType.tv);
      expect(MediaType.tryParse('person'), MediaType.person);
    });

    test('ignora mayúsculas y espacios', () {
      expect(MediaType.tryParse(' MOVIE '), MediaType.movie);
    });

    test('devuelve null ante valores desconocidos', () {
      expect(MediaType.tryParse('documental'), isNull);
      expect(MediaType.tryParse(null), isNull);
      expect(MediaType.tryParse(''), isNull);
    });

    test('parse aplica el valor de reserva', () {
      expect(MediaType.parse('raro'), MediaType.movie);
      expect(MediaType.parse(null, fallback: MediaType.tv), MediaType.tv);
    });

    test('expone las rutas de la API de TMDB', () {
      expect(MediaType.movie.apiValue, 'movie');
      expect(MediaType.tv.apiValue, 'tv');
    });
  });

  group('TmdbImages.url', () {
    test('compone la URL con el CDN y el tamaño', () {
      expect(
        TmdbImages.url('/abc123.jpg', TmdbImageSize.posterMedium),
        'https://image.tmdb.org/t/p/w342/abc123.jpg',
      );
    });

    test('añade la barra inicial si falta', () {
      expect(
        TmdbImages.url('abc.jpg', 'w185'),
        'https://image.tmdb.org/t/p/w185/abc.jpg',
      );
    });

    test('devuelve null si no hay imagen', () {
      expect(TmdbImages.url(null, 'w342'), isNull);
      expect(TmdbImages.url('', 'w342'), isNull);
      expect(TmdbImages.url('   ', 'w342'), isNull);
    });

    test('no reescribe URLs absolutas', () {
      const String externa = 'https://cdn.example.com/avatar.png';
      expect(TmdbImages.url(externa, 'w342'), externa);
    });

    test('los accesos rápidos usan el tamaño correcto', () {
      expect(TmdbImages.poster('/p.jpg'), contains('/w342/p.jpg'));
      expect(TmdbImages.posterLarge('/p.jpg'), contains('/w500/p.jpg'));
      expect(TmdbImages.backdrop('/b.jpg'), contains('/w1280/b.jpg'));
      expect(TmdbImages.profile('/f.jpg'), contains('/w185/f.jpg'));
      expect(TmdbImages.still('/s.jpg'), contains('/w780/s.jpg'));
    });
  });

  group('TmdbSortBy.label', () {
    test('etiqueta los criterios conocidos', () {
      expect(TmdbSortBy.label(TmdbSortBy.popularityDesc), 'Popularidad');
      expect(TmdbSortBy.label(TmdbSortBy.voteAverageDesc), 'Mejor valoradas');
    });

    test('devuelve el valor crudo si no lo conoce', () {
      expect(TmdbSortBy.label('invento.desc'), 'invento.desc');
    });

    test('todos los criterios tienen etiqueta propia', () {
      for (final String sortBy in TmdbSortBy.all) {
        expect(TmdbSortBy.label(sortBy), isNot(sortBy));
      }
    });
  });

  group('pickBestTrailer', () {
    MediaVideo video({
      required String type,
      bool official = true,
      DateTime? publishedAt,
    }) => MediaVideo(
      id: 'id-$type-${official ? 'o' : 'n'}-${publishedAt?.millisecondsSinceEpoch ?? 0}',
      key: 'KEY$type',
      name: type,
      site: 'YouTube',
      type: type,
      official: official,
      publishedAt: publishedAt,
    );

    test('devuelve null con lista vacía', () {
      expect(pickBestTrailer(<MediaVideo>[]), isNull);
    });

    test('prefiere un tráiler oficial a un teaser oficial', () {
      final MediaVideo? picked = pickBestTrailer(<MediaVideo>[
        video(type: 'Teaser'),
        video(type: 'Trailer'),
      ]);
      expect(picked?.type, 'Trailer');
    });

    test('prefiere oficial frente a no oficial del mismo tipo', () {
      final MediaVideo? picked = pickBestTrailer(<MediaVideo>[
        video(type: 'Trailer', official: false),
        video(type: 'Trailer', official: true),
      ]);
      expect(picked?.official, isTrue);
    });

    test('a igual puntuación se queda con el más reciente', () {
      final MediaVideo? picked = pickBestTrailer(<MediaVideo>[
        video(type: 'Trailer', publishedAt: DateTime(2020)),
        video(type: 'Trailer', publishedAt: DateTime(2024)),
      ]);
      expect(picked?.publishedAt, DateTime(2024));
    });

    test('devuelve algo aunque solo haya clips', () {
      final MediaVideo? picked = pickBestTrailer(<MediaVideo>[
        video(type: 'Behind the Scenes'),
      ]);
      expect(picked, isNotNull);
    });

    test('las URLs de YouTube se componen correctamente', () {
      final MediaVideo v = video(type: 'Trailer');
      expect(v.watchUrl, 'https://www.youtube.com/watch?v=KEYTrailer');
      expect(v.thumbnailUrl, contains('img.youtube.com'));
      expect(v.isYoutube, isTrue);
    });
  });
}
