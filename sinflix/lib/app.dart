import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/core_providers.dart';
import 'presentation/router/app_router.dart';

/// Widget raíz de SinFlix.
///
/// No contiene lógica de negocio: solo engancha el router, el tema y la
/// localización. Todo el estado se gestiona mediante Riverpod.
class SinFlixApp extends ConsumerWidget {
  const SinFlixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: Strings.appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: ref.watch(routerProvider),

      // Localización: español por defecto e inglés como reserva, para que los
      // widgets de Material (fechas, diálogos, accesibilidad) estén traducidos.
      locale: const Locale('es'),
      supportedLocales: const <Locale>[Locale('es'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Se limita el escalado de texto: con la accesibilidad al máximo, las
      // tarjetas de póster y las barras se rompen en pantallas pequeñas.
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData media = MediaQuery.of(context);
        final double scale = media.textScaler.scale(1).clamp(0.85, 1.35);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
