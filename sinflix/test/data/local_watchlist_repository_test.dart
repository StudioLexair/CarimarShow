import 'package:flutter_test/flutter_test.dart';
import 'package:sinflix/data/mappers/local_codec.dart';
import 'package:sinflix/data/repositories/local_watchlist_repository.dart';
import 'package:sinflix/domain/entities/media_id.dart';
import 'package:sinflix/domain/entities/media_item.dart';
import 'package:sinflix/domain/entities/media_type.dart';
import 'package:sinflix/domain/entities/watchlist_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

const MediaItem _movie = MediaItem(
  id: 155,
  type: MediaType.movie,
  title: 'Título de prueba',
  originalTitle: 'Original',
  overview: 'Sinopsis de prueba.',
  posterPath: '/poster.jpg',
  backdropPath: '/backdrop.jpg',
  voteAverage: 8.5,
  voteCount: 1200,
  genreIds: <int>[18, 80],
  originalLanguage: 'es',
  popularity: 42.5,
);

const MediaItem _tv = MediaItem(
  id: 1396,
  type: MediaType.tv,
  title: 'Serie de prueba',
  overview: '',
  voteAverage: 0,
  releaseDate: null,
);

void main() {
  group('MediaId', () {
    test('compone y descompone la clave canónica', () {
      const MediaId id = MediaId(MediaType.movie, 155);
      expect(id.key, 'movie:155');
      expect(MediaId.tryParse('movie:155'), id);
      expect(MediaId.tryParse('tv:1396'), const MediaId(MediaType.tv, 1396));
    });

    test('rechaza claves malformadas sin lanzar', () {
      expect(MediaId.tryParse(''), isNull);
      expect(MediaId.tryParse('movie'), isNull);
      expect(MediaId.tryParse(':155'), isNull);
      expect(MediaId.tryParse('movie:'), isNull);
      expect(MediaId.tryParse('movie:abc'), isNull);
      expect(MediaId.tryParse('person:5'), isNull);
      expect(MediaId.tryParse('invento:5'), isNull);
    });

    test('parse lanza ante claves inválidas', () {
      expect(() => MediaId.parse('basura'), throwsFormatException);
    });

    test('genera la ruta de la ficha', () {
      expect(const MediaId(MediaType.tv, 7).route, '/title/tv/7');
    });

    test('coincide con MediaItem.uniqueKey', () {
      expect(MediaId(_movie.type, _movie.id).key, _movie.uniqueKey);
    });

    test('película y serie con el mismo id no colisionan', () {
      const MediaId movie = MediaId(MediaType.movie, 155);
      const MediaId tv = MediaId(MediaType.tv, 155);
      expect(movie, isNot(tv));
      expect(movie.key, isNot(tv.key));
    });
  });

  group('LocalCodec', () {
    test('ida y vuelta de un elemento de catálogo', () {
      final WatchlistItem? decoded = LocalCodec.decodeWatchlistItem(
        LocalCodec.encodeWatchlistItem(WatchlistItem.create(_movie)),
      );
      expect(decoded, isNotNull);
      expect(decoded!.media, _movie);
      expect(decoded.status, WatchlistStatus.planned);
    });

    test('preserva campos opcionales nulos', () {
      final WatchlistItem? decoded = LocalCodec.decodeWatchlistItem(
        LocalCodec.encodeWatchlistItem(WatchlistItem.create(_tv)),
      );
      expect(decoded?.media.releaseDate, isNull);
      expect(decoded?.media.voteAverage, 0);
      expect(decoded?.media.overview, '');
    });

    test('devuelve null ante basura en vez de lanzar', () {
      expect(LocalCodec.decodeWatchlistItem(null), isNull);
      expect(LocalCodec.decodeWatchlistItem('texto'), isNull);
      expect(LocalCodec.decodeWatchlistItem(<String, dynamic>{}), isNull);
      expect(
        LocalCodec.decodeWatchlistItem(<String, dynamic>{
          'media': 'no-es-mapa',
        }),
        isNull,
      );
    });

    test('decodeWatchlist descarta entradas corruptas y ordena por fecha', () {
      final WatchlistItem vieja = WatchlistItem(
        media: _movie,
        status: WatchlistStatus.planned,
        addedAt: DateTime(2020),
      );
      final WatchlistItem nueva = WatchlistItem(
        media: _tv,
        status: WatchlistStatus.watching,
        addedAt: DateTime(2024),
      );

      final List<WatchlistItem> result = LocalCodec.decodeWatchlist(<Object?>[
        LocalCodec.encodeWatchlistItem(vieja),
        'entrada-corrupta',
        null,
        LocalCodec.encodeWatchlistItem(nueva),
      ]);

      expect(result, hasLength(2));
      expect(
        result.first.media.id,
        _tv.id,
        reason: 'la más reciente va primero',
      );
      expect(result.last.media.id, _movie.id);
    });

    test('decodeWatchlist acepta una lista vacía o nula', () {
      expect(LocalCodec.decodeWatchlist(null), isEmpty);
      expect(LocalCodec.decodeWatchlist(<Object?>[]), isEmpty);
    });
  });

  group('LocalWatchlistRepository', () {
    late LocalWatchlistRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      repository = LocalWatchlistRepository();
      await repository.initialize(prefs);
    });

    tearDown(() => repository.dispose());

    test('empieza vacía y no está sincronizada', () async {
      expect(repository.isRemote, isFalse);
      expect(await repository.fetch('u1'), isEmpty);
    });

    test('toggle añade y luego quita', () async {
      expect(await repository.toggle('u1', _movie), isTrue);
      expect(await repository.contains('u1', _movie.uniqueKey), isTrue);

      expect(await repository.toggle('u1', _movie), isFalse);
      expect(await repository.contains('u1', _movie.uniqueKey), isFalse);
      expect(await repository.fetch('u1'), isEmpty);
    });

    test('add no duplica un título ya guardado', () async {
      await repository.add('u1', _movie);
      await repository.add('u1', _movie);
      expect(await repository.fetch('u1'), hasLength(1));
    });

    test('película y serie con el mismo id conviven', () async {
      const MediaItem tvMismoId = MediaItem(
        id: 155,
        type: MediaType.tv,
        title: 'Otra',
        overview: '',
      );
      await repository.add('u1', _movie);
      await repository.add('u1', tvMismoId);
      final List<WatchlistItem> list = await repository.fetch('u1');
      expect(list, hasLength(2));
      expect(list.map((WatchlistItem i) => i.key).toSet(), <String>{
        'movie:155',
        'tv:155',
      });
    });

    test('cada usuario tiene su propia lista', () async {
      await repository.add('u1', _movie);
      await repository.add('u2', _tv);
      expect(await repository.fetch('u1'), hasLength(1));
      expect(await repository.fetch('u2'), hasLength(1));
      expect((await repository.fetch('u1')).single.media.id, _movie.id);
      expect((await repository.fetch('u2')).single.media.id, _tv.id);
    });

    test('remove elimina solo la clave indicada', () async {
      await repository.add('u1', _movie);
      await repository.add('u1', _tv);
      await repository.remove('u1', _movie.uniqueKey);
      final List<WatchlistItem> list = await repository.fetch('u1');
      expect(list, hasLength(1));
      expect(list.single.key, _tv.uniqueKey);
    });

    test('remove con clave inexistente no lanza', () async {
      await repository.add('u1', _movie);
      await repository.remove('u1', 'movie:99999');
      expect(await repository.fetch('u1'), hasLength(1));
    });

    test('updateStatus cambia el estado y ajusta el progreso', () async {
      await repository.add('u1', _movie);

      await repository.updateStatus(
        'u1',
        _movie.uniqueKey,
        WatchlistStatus.completed,
      );
      WatchlistItem item = (await repository.fetch('u1')).single;
      expect(item.status, WatchlistStatus.completed);
      expect(item.progressPercent, 100);
      expect(item.isCompleted, isTrue);

      await repository.updateStatus(
        'u1',
        _movie.uniqueKey,
        WatchlistStatus.watching,
      );
      item = (await repository.fetch('u1')).single;
      expect(item.status, WatchlistStatus.watching);
      expect(item.isWatching, isTrue);
    });

    test('updateStatus sobre una clave inexistente no lanza', () async {
      await repository.updateStatus('u1', 'tv:1', WatchlistStatus.planned);
      expect(await repository.fetch('u1'), isEmpty);
    });

    test('updateProgress deriva el estado y recorta al rango 0-100', () async {
      await repository.add('u1', _movie);

      await repository.updateProgress('u1', _movie.uniqueKey, 40);
      WatchlistItem item = (await repository.fetch('u1')).single;
      expect(item.progressPercent, 40);
      expect(item.status, WatchlistStatus.watching);

      await repository.updateProgress('u1', _movie.uniqueKey, 100);
      item = (await repository.fetch('u1')).single;
      expect(item.status, WatchlistStatus.completed);

      await repository.updateProgress('u1', _movie.uniqueKey, 500);
      expect((await repository.fetch('u1')).single.progressPercent, 100);

      await repository.updateProgress('u1', _movie.uniqueKey, -20);
      expect((await repository.fetch('u1')).single.progressPercent, 0);
    });

    test('clear vacía la lista', () async {
      await repository.add('u1', _movie);
      await repository.add('u1', _tv);
      await repository.clear('u1');
      expect(await repository.fetch('u1'), isEmpty);
    });

    test('watch emite el estado inicial y los cambios posteriores', () async {
      final Future<List<List<WatchlistItem>>> emisiones = repository
          .watch('u1')
          .take(2)
          .toList();

      // Pequeña espera para que la suscripción esté activa antes de mutar.
      await Future<void>.delayed(Duration.zero);
      await repository.add('u1', _movie);

      final List<List<WatchlistItem>> recibidas = await emisiones;
      expect(recibidas, hasLength(2));
      expect(recibidas[0], isEmpty, reason: 'primera emisión: lista vacía');
      expect(
        recibidas[1],
        hasLength(1),
        reason: 'segunda emisión: tras añadir',
      );
    });

    test('persiste entre instancias del repositorio', () async {
      await repository.add('u1', _movie);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalWatchlistRepository otra = LocalWatchlistRepository();
      await otra.initialize(prefs);
      addTearDown(otra.dispose);

      final List<WatchlistItem> restaurada = await otra.fetch('u1');
      expect(restaurada, hasLength(1));
      expect(restaurada.single.media, _movie);
      expect(restaurada.single.status, WatchlistStatus.planned);
    });

    test('una lista persistida corrupta no bloquea el arranque', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('sinflix.watchlist.u1', '{json roto');

      final LocalWatchlistRepository otra = LocalWatchlistRepository();
      await otra.initialize(prefs);
      addTearDown(otra.dispose);

      expect(await otra.fetch('u1'), isEmpty);
      // Y sigue siendo usable después.
      await otra.add('u1', _movie);
      expect(await otra.fetch('u1'), hasLength(1));
    });
  });

  group('WatchlistItem', () {
    test('create marca como pendiente y fecha la entrada', () {
      final WatchlistItem item = WatchlistItem.create(_movie);
      expect(item.status, WatchlistStatus.planned);
      expect(item.addedAt, isNotNull);
      expect(item.key, 'movie:155');
      expect(item.tmdbId, 155);
      expect(item.type, MediaType.movie);
      expect(item.title, 'Título de prueba');
    });

    test('copyWith solo cambia lo indicado', () {
      final WatchlistItem original = WatchlistItem.create(_movie);
      final WatchlistItem copia = original.copyWith(
        status: WatchlistStatus.watching,
      );
      expect(copia.status, WatchlistStatus.watching);
      expect(copia.media, original.media);
      expect(copia.addedAt, original.addedAt);
      expect(copia, isNot(original));
    });
  });

  group('WatchlistStatus.parse', () {
    test('reconoce los valores guardados', () {
      expect(WatchlistStatus.parse('watching'), WatchlistStatus.watching);
      expect(WatchlistStatus.parse('completed'), WatchlistStatus.completed);
    });

    test('degrada a pendiente ante valores desconocidos', () {
      expect(WatchlistStatus.parse(null), WatchlistStatus.planned);
      expect(WatchlistStatus.parse('invento'), WatchlistStatus.planned);
    });
  });
}
