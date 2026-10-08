import 'package:flutter_test/flutter_test.dart';
import 'package:carimarshow/data/mappers/media_mapper.dart';
import 'package:carimarshow/domain/entities/media_details.dart';
import 'package:carimarshow/domain/entities/media_item.dart';
import 'package:carimarshow/domain/entities/media_type.dart';

/// Respuesta real de `/movie/popular` (película).
const Map<String, dynamic> _movieJson = <String, dynamic>{
  'adult': false,
  'backdrop_path': '/backdrop.jpg',
  'genre_ids': <int>[18, 80],
  'id': 155,
  'original_language': 'en',
  'original_title': 'The Dark Knight',
  'overview': 'Batman raises the stakes.',
  'popularity': 123.14,
  'poster_path': '/poster.jpg',
  'release_date': '2008-07-16',
  'title': 'The Dark Knight',
  'video': false,
  'vote_average': 8.517,
  'vote_count': 30799,
};

/// Respuesta real de `/tv/popular` (serie): usa `name` y `first_air_date`.
const Map<String, dynamic> _tvJson = <String, dynamic>{
  'backdrop_path': '/tvbackdrop.jpg',
  'first_air_date': '2008-01-20',
  'genre_ids': <int>[18],
  'id': 1396,
  'name': 'Breaking Bad',
  'origin_country': <String>['US'],
  'original_language': 'en',
  'original_name': 'Breaking Bad',
  'overview': 'A high school teacher turns to crime.',
  'popularity': 400.5,
  'poster_path': '/tvposter.jpg',
  'vote_average': 8.9,
  'vote_count': 12000,
};

/// Elemento de `/search/multi`, que sí trae `media_type`.
Map<String, dynamic> _multiJson(String mediaType, int id) => <String, dynamic>{
  ..._movieJson,
  'media_type': mediaType,
  'id': id,
};

void main() {
  group('MediaMapper.item (película)', () {
    final MediaItem item = MediaMapper.item(
      _movieJson,
      fallbackType: MediaType.movie,
    );

    test('mapea los campos principales', () {
      expect(item.id, 155);
      expect(item.type, MediaType.movie);
      expect(item.title, 'The Dark Knight');
      expect(item.overview, 'Batman raises the stakes.');
      expect(item.posterPath, '/poster.jpg');
      expect(item.backdropPath, '/backdrop.jpg');
      expect(item.voteAverage, 8.517);
      expect(item.voteCount, 30799);
      expect(item.genreIds, <int>[18, 80]);
      expect(item.originalLanguage, 'en');
    });

    test('convierte release_date en DateTime', () {
      expect(item.releaseDate, DateTime(2008, 7, 16));
      expect(item.year, 2008);
    });

    test('genera una clave única que incluye el tipo', () {
      expect(item.uniqueKey, 'movie:155');
    });

    test('detecta la presencia de imágenes', () {
      expect(item.hasPoster, isTrue);
      expect(item.hasBackdrop, isTrue);
      expect(item.hasVote, isTrue);
    });
  });

  group('MediaMapper.item (serie)', () {
    final MediaItem item = MediaMapper.item(
      _tvJson,
      fallbackType: MediaType.tv,
    );

    test('usa `name` cuando falta `title`', () {
      expect(item.title, 'Breaking Bad');
      expect(item.originalTitle, 'Breaking Bad');
    });

    test('usa `first_air_date` como fecha de estreno', () {
      expect(item.releaseDate, DateTime(2008, 1, 20));
      expect(item.year, 2008);
    });

    test('respeta el tipo de reserva', () {
      expect(item.type, MediaType.tv);
      expect(item.uniqueKey, 'tv:1396');
    });
  });

  group('MediaMapper y media_type explícito', () {
    test('media_type gana sobre el tipo de reserva', () {
      final MediaItem fromMulti = MediaMapper.item(
        _multiJson('tv', 1396),
        fallbackType: MediaType.movie,
      );
      expect(fromMulti.type, MediaType.tv);
    });
  });

  group('Tolerancia a datos incompletos', () {
    test('sin id devuelve null en vez de un título inválido', () {
      expect(MediaMapper.itemOrNull(<String, dynamic>{'title': 'X'}), isNull);
      expect(MediaMapper.itemOrNull(<String, dynamic>{'id': 0}), isNull);
    });

    test('descarta personas, que no son títulos', () {
      expect(
        MediaMapper.itemOrNull(<String, dynamic>{
          'id': 5,
          'media_type': 'person',
          'name': 'Alguien',
        }),
        isNull,
      );
    });

    test('sobrevive a un JSON casi vacío', () {
      final MediaItem item = MediaMapper.item(<String, dynamic>{
        'id': 1,
      }, fallbackType: MediaType.movie);
      expect(item.title, '');
      expect(item.displayTitle, 'Sin título');
      expect(item.hasPoster, isFalse);
      expect(item.hasVote, isFalse);
      expect(item.releaseDate, isNull);
      expect(item.genreIds, isEmpty);
    });

    test('items filtra entradas inválidas sin abortar la lista', () {
      final List<MediaItem> items = MediaMapper.items(<Map<String, dynamic>>[
        _movieJson,
        <String, dynamic>{'title': 'sin id'},
        _tvJson,
      ]);
      expect(items, hasLength(2));
      expect(items.map((MediaItem i) => i.id).toList(), <int>[155, 1396]);
    });

    test('items aplica el tipo de reserva cuando el JSON no trae media_type', () {
      // Ninguno de los dos endpoints de listado incluye `media_type`: el tipo lo
      // decide la ruta consultada, por eso se pasa como reserva.
      final List<MediaItem> comoSerie = MediaMapper.items(
        <Map<String, dynamic>>[_tvJson],
        fallbackType: MediaType.tv,
      );
      expect(comoSerie.single.uniqueKey, 'tv:1396');

      // Y si el JSON sí lo trae (búsqueda multi, tendencias globales), manda.
      final List<MediaItem> conTipo = MediaMapper.items(<Map<String, dynamic>>[
        _multiJson('tv', 1396),
      ], fallbackType: MediaType.movie);
      expect(conTipo.single.uniqueKey, 'tv:1396');
    });

    test('items respeta el límite', () {
      final List<MediaItem> items = MediaMapper.items(<Map<String, dynamic>>[
        _movieJson,
        _tvJson,
      ], limit: 1);
      expect(items, hasLength(1));
    });

    test('items excluye contenido para adultos si se pide', () {
      final List<MediaItem> items = MediaMapper.items(<Map<String, dynamic>>[
        _movieJson,
        <String, dynamic>{..._movieJson, 'id': 999, 'adult': true},
      ], excludeAdult: true);
      expect(items, hasLength(1));
      expect(items.single.id, 155);
    });
  });

  group('MediaMapper.details', () {
    /// Ficha completa tal y como la devuelve `append_to_response`.
    final Map<String, dynamic> full = <String, dynamic>{
      ..._movieJson,
      'tagline': 'Why so serious?',
      'status': 'Released',
      'runtime': 152,
      'budget': 185000000,
      'revenue': 1004558444,
      'imdb_id': 'tt0468569',
      'homepage': 'https://example.com',
      'genres': <Map<String, dynamic>>[
        <String, dynamic>{'id': 18, 'name': 'Drama'},
        <String, dynamic>{'id': 80, 'name': 'Crimen'},
      ],
      'production_countries': <Map<String, dynamic>>[
        <String, dynamic>{'iso_3166_1': 'US', 'name': 'Estados Unidos'},
      ],
      'spoken_languages': <Map<String, dynamic>>[
        <String, dynamic>{
          'english_name': 'English',
          'iso_639_1': 'en',
          'name': 'English',
        },
      ],
      'credits': <String, dynamic>{
        'cast': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'name': 'Actor Uno',
            'character': 'Héroe',
            'order': 0,
            'profile_path': '/a1.jpg',
          },
          <String, dynamic>{'id': 2, 'name': '', 'character': 'Ignorado'},
        ],
        'crew': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 9,
            'name': 'Director Uno',
            'job': 'Director',
            'department': 'Directing',
          },
        ],
      },
      'videos': <String, dynamic>{
        'results': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'v1',
            'key': 'ABC',
            'name': 'Clip',
            'site': 'YouTube',
            'type': 'Clip',
            'official': false,
          },
          <String, dynamic>{
            'id': 'v2',
            'key': 'XYZ',
            'name': 'Tráiler',
            'site': 'YouTube',
            'type': 'Trailer',
            'official': true,
          },
          <String, dynamic>{'id': 'v3', 'key': '', 'name': 'Sin key'},
        ],
      },
      'similar': <String, dynamic>{
        'results': <Map<String, dynamic>>[
          <String, dynamic>{..._movieJson, 'id': 500},
        ],
      },
      'recommendations': <String, dynamic>{
        'results': <Map<String, dynamic>>[
          <String, dynamic>{..._movieJson, 'id': 501},
        ],
      },
      'keywords': <String, dynamic>{
        'keywords': <Map<String, dynamic>>[
          <String, dynamic>{'id': 1, 'name': 'superhéroe'},
        ],
      },
    };

    final MediaDetails details = MediaMapper.details(
      full,
      type: MediaType.movie,
    );

    test('reutiliza el elemento base', () {
      expect(details.id, 155);
      expect(details.title, 'The Dark Knight');
      expect(details.item.uniqueKey, 'movie:155');
    });

    test('mapea géneros, países e idiomas', () {
      expect(details.genreNames, <String>['Drama', 'Crimen']);
      expect(details.productionCountries, <String>['Estados Unidos']);
      expect(details.spokenLanguages, <String>['English']);
    });

    test('mapea campos de película', () {
      expect(details.tagline, 'Why so serious?');
      expect(details.hasTagline, isTrue);
      expect(details.status, 'Released');
      expect(details.runtime, 152);
      expect(details.budget, 185000000);
      expect(details.imdbId, 'tt0468569');
    });

    test('descarta miembros del reparto sin nombre', () {
      expect(details.cast, hasLength(1));
      expect(details.cast.single.name, 'Actor Uno');
      expect(details.cast.single.character, 'Héroe');
      expect(details.cast.single.subtitle, 'Héroe');
    });

    test('extrae directores del equipo técnico', () {
      expect(details.directors, <String>['Director Uno']);
    });

    test('ignora vídeos sin key y elige el tráiler oficial', () {
      expect(details.videos, hasLength(2));
      expect(details.hasTrailer, isTrue);
      expect(details.trailer?.type, 'Trailer');
      expect(details.trailer?.official, isTrue);
    });

    test('desanida similar y recomendaciones de append_to_response', () {
      expect(details.similar, hasLength(1));
      expect(details.similar.single.id, 500);
      expect(details.recommendations, hasLength(1));
      expect(details.recommendations.single.id, 501);
    });

    test('extrae palabras clave con la estructura de película', () {
      expect(details.keywords, <String>['superhéroe']);
    });

    test('construye las URLs externas', () {
      expect(details.tmdbUrl, 'https://www.themoviedb.org/movie/155');
      expect(details.imdbUrl, 'https://www.imdb.com/title/tt0468569/');
    });

    test('una película no trae temporadas', () {
      expect(details.seasons, isEmpty);
      expect(details.regularSeasons, isEmpty);
    });
  });

  group('MediaMapper.details (serie)', () {
    final Map<String, dynamic> full = <String, dynamic>{
      ..._tvJson,
      'created_by': <Map<String, dynamic>>[
        <String, dynamic>{'id': 7, 'name': 'Creador Uno'},
      ],
      'number_of_seasons': 5,
      'number_of_episodes': 62,
      'episode_run_time': <int>[47, 45],
      'in_production': false,
      'last_air_date': '2013-09-29',
      'status': 'Ended',
      'next_episode_to_air': <String, dynamic>{
        'episode_number': 1,
        'season_number': 6,
        'name': 'Regreso',
        'overview': '',
        'runtime': 45,
      },
      'seasons': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': 'Especiales',
          'season_number': 0,
          'episode_count': 3,
          'overview': '',
        },
        <String, dynamic>{
          'id': 2,
          'name': 'Temporada 1',
          'season_number': 1,
          'episode_count': 7,
          'air_date': '2008-01-20',
          'overview': '',
        },
      ],
      'keywords': <String, dynamic>{
        // Las series usan `results`, no `keywords`.
        'results': <Map<String, dynamic>>[
          <String, dynamic>{'id': 2, 'name': 'metanfetamina'},
        ],
      },
    };

    final MediaDetails details = MediaMapper.details(full, type: MediaType.tv);

    test('mapea los campos específicos de serie', () {
      expect(details.createdBy, <String>['Creador Uno']);
      expect(details.numberOfSeasons, 5);
      expect(details.numberOfEpisodes, 62);
      expect(details.episodeRuntimes, <int>[47, 45]);
      expect(details.inProduction, isFalse);
      expect(details.lastAirDate, DateTime(2013, 9, 29));
    });

    test('regularSeasons excluye los especiales', () {
      expect(details.seasons, hasLength(2));
      expect(details.regularSeasons, hasLength(1));
      expect(details.regularSeasons.single.number, 1);
      expect(details.regularSeasons.single.episodeCount, 7);
    });

    test('detecta el próximo episodio', () {
      expect(details.nextEpisodeToAir, isNotNull);
      expect(details.nextEpisodeToAir?.shortCode, '6x01');
    });

    test('extrae palabras clave con la estructura de serie', () {
      expect(details.keywords, <String>['metanfetamina']);
    });

    test('la URL externa apunta a /tv/', () {
      expect(details.tmdbUrl, 'https://www.themoviedb.org/tv/1396');
      // Sin imdb_id, la URL de IMDB degrada a la de TMDB en vez de romperse.
      expect(details.imdbUrl, details.tmdbUrl);
    });
  });

  group('MediaMapper.genres', () {
    test('descarta géneros sin id o sin nombre', () {
      final List<dynamic> genres = MediaMapper.genres(<String, dynamic>{
        'genres': <Map<String, dynamic>>[
          <String, dynamic>{'id': 28, 'name': 'Acción'},
          <String, dynamic>{'id': 0, 'name': 'Inválido'},
          <String, dynamic>{'id': 12, 'name': ''},
        ],
      });
      expect(genres, hasLength(1));
    });
  });

  group('MediaMapper.episodes', () {
    test('numera y descarta episodios sin número', () {
      final List<dynamic> episodes = MediaMapper.episodes(<String, dynamic>{
        'episodes': <Map<String, dynamic>>[
          <String, dynamic>{
            'episode_number': 1,
            'season_number': 1,
            'name': 'Piloto',
            'overview': '',
            'runtime': 58,
          },
          <String, dynamic>{'name': 'Sin número', 'overview': ''},
        ],
      });
      expect(episodes, hasLength(1));
    });
  });
}
