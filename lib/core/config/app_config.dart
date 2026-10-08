import 'package:equatable/equatable.dart';

import 'env.dart';

/// Configuración resuelta de la aplicación, lista para inyectar vía Riverpod.
///
/// Agrupa lo que viene del entorno y lo que es decisión de producto, de forma
/// que el resto del código nunca dependa directamente de `String.fromEnvironment`.
class AppConfig extends Equatable {
  const AppConfig({
    required this.environment,
    required this.tmdbReadToken,
    required this.tmdbApiKey,
    required this.language,
    required this.region,
    required this.supabaseUrl,
    required this.supabaseKey,
    required this.useDemoCatalog,
  });

  /// Construye la configuración a partir de las variables de entorno.
  factory AppConfig.fromEnv() => AppConfig(
    environment: Env.environment,
    tmdbReadToken: Env.tmdbReadToken,
    tmdbApiKey: Env.tmdbApiKey,
    language: Env.tmdbLanguage,
    region: Env.tmdbRegion,
    supabaseUrl: Env.supabaseUrl,
    supabaseKey: Env.supabaseKey,
    useDemoCatalog: Env.isDemoMode,
  );

  final AppEnvironment environment;

  final String tmdbReadToken;
  final String tmdbApiKey;
  final String language;
  final String region;

  final String supabaseUrl;
  final String supabaseKey;

  /// Cuando no hay credenciales de TMDB se sirve el catálogo local de demo.
  final bool useDemoCatalog;

  bool get isTmdbEnabled => !useDemoCatalog;
  bool get isAccountsEnabled =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  @override
  List<Object?> get props => <Object?>[
    environment,
    tmdbReadToken,
    tmdbApiKey,
    language,
    region,
    supabaseUrl,
    supabaseKey,
    useDemoCatalog,
  ];
}
