import 'package:equatable/equatable.dart';

/// Género de TMDB (`/genre/movie/list`, `/genre/tv/list`).
class Genre extends Equatable {
  const Genre({required this.id, required this.name});

  final int id;
  final String name;

  @override
  List<Object?> get props => <Object?>[id, name];
}
