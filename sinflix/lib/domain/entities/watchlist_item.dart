import 'package:equatable/equatable.dart';

import 'media_item.dart';
import 'media_type.dart';

/// Estado de seguimiento de un título en la lista del usuario.
enum WatchlistStatus {
  /// Guardado para ver más adelante.
  planned('Pendiente'),

  /// Empezado pero sin terminar.
  watching('Viendo'),

  /// Ya visto.
  completed('Completado');

  const WatchlistStatus(this.label);
  final String label;

  static WatchlistStatus parse(String? raw) =>
      WatchlistStatus.values.firstWhere(
        (WatchlistStatus s) => s.name == raw,
        orElse: () => WatchlistStatus.planned,
      );
}

/// Entrada de «Mi lista».
///
/// Guarda el [MediaItem] completo para poder pintar póster y título sin volver
/// a consultar TMDB: la lista se muestra igual de bien sin conexión.
class WatchlistItem extends Equatable {
  const WatchlistItem({
    required this.media,
    required this.status,
    required this.addedAt,
    this.updatedAt,
    this.progressPercent,
    this.note,
  });

  /// Crea una entrada nueva en estado «pendiente».
  factory WatchlistItem.create(MediaItem media) {
    final DateTime now = DateTime.now();
    return WatchlistItem(
      media: media,
      status: WatchlistStatus.planned,
      addedAt: now,
      updatedAt: now,
    );
  }

  final MediaItem media;
  final WatchlistStatus status;
  final DateTime addedAt;
  final DateTime? updatedAt;

  /// Progreso de visionado (0–100), útil para «continuar viendo».
  final int? progressPercent;

  final String? note;

  /// Clave única: tipo + id de TMDB.
  String get key => media.uniqueKey;

  int get tmdbId => media.id;

  MediaType get type => media.type;

  String get title => media.displayTitle;

  bool get isWatching => status == WatchlistStatus.watching;

  bool get isCompleted => status == WatchlistStatus.completed;

  WatchlistItem copyWith({
    MediaItem? media,
    WatchlistStatus? status,
    DateTime? addedAt,
    DateTime? updatedAt,
    int? progressPercent,
    String? note,
  }) => WatchlistItem(
    media: media ?? this.media,
    status: status ?? this.status,
    addedAt: addedAt ?? this.addedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    progressPercent: progressPercent ?? this.progressPercent,
    note: note ?? this.note,
  );

  @override
  List<Object?> get props => <Object?>[
    media,
    status,
    addedAt,
    updatedAt,
    progressPercent,
    note,
  ];
}
