import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Construcción del tema de CarimarShow.
///
/// La app es oscura por diseño (un catálogo de cine se ve mejor así), pero se
/// expone [buildLight] para quien prefiera forzar el tema claro desde Ajustes.
/// Colores que CAMBIAN entre el tema claro y el oscuro.
///
/// Hasta ahora los widgets leían superficies y textos de [AppColors], que son
/// constantes oscuras: el tema claro salía con tarjetas negras sobre fondo
/// blanco. Esta extensión es la única fuente de verdad de esos colores y cada
/// tema registra su instancia, así que `context.pal.surface` da el valor
/// correcto en cualquier modo sin cambiar una sola llamada en los widgets.
class AppPal extends ThemeExtension<AppPal> {
  const AppPal({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
  });

  /// Azul noche profundo con tinte turquesa.
  static const AppPal dark = AppPal(
    background: Color(0xFF06161C),
    surface: Color(0xFF0B232B),
    surfaceHigh: Color(0xFF10303A),
    surfaceHighest: Color(0xFF16404B),
    outline: Color(0xFF1E4A57),
    textPrimary: Color(0xFFEAF7F9),
    textSecondary: Color(0xFFA7C6CD),
    textDisabled: Color(0xFF628891),
  );

  /// Menta muy claro, tarjetas blancas y texto azul tinta: legible y acorde
  /// al logotipo, no un gris genérico de Material.
  static const AppPal light = AppPal(
    background: Color(0xFFF2F8F9),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFE8F3F5),
    surfaceHighest: Color(0xFFDCEBED),
    outline: Color(0xFFB9D4DA),
    textPrimary: Color(0xFF0B2E38),
    textSecondary: Color(0xFF40626C),
    textDisabled: Color(0xFF7FA0A9),
  );

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color surfaceHighest;
  final Color outline;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;

  @override
  AppPal copyWith({
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? surfaceHighest,
    Color? outline,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
  }) => AppPal(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceHigh: surfaceHigh ?? this.surfaceHigh,
    surfaceHighest: surfaceHighest ?? this.surfaceHighest,
    outline: outline ?? this.outline,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textDisabled: textDisabled ?? this.textDisabled,
  );

  @override
  AppPal lerp(AppPal? other, double t) => other == null
      ? this
      : AppPal(
          background: Color.lerp(background, other.background, t)!,
          surface: Color.lerp(surface, other.surface, t)!,
          surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
          surfaceHighest: Color.lerp(surfaceHighest, other.surfaceHighest, t)!,
          outline: Color.lerp(outline, other.outline, t)!,
          textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
          textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
          textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
        );
}

abstract final class AppTheme {
  static const double _radius = 18;

  /// Tema oscuro por defecto.
  static ThemeData dark() => _base(Brightness.dark);

  /// Tema claro alternativo.
  static ThemeData light() => _base(Brightness.light);

  static ThemeData _base(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final AppPal pal = isDark ? AppPal.dark : AppPal.light;

    // Nota: no se usan `background`/`onBackground` porque quedaron retirados
    // de ColorScheme en favor de `surface`/`onSurface` + los contenedores.
    final ColorScheme resolved =
        ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.accent,
          onPrimary: isDark ? Colors.white : Colors.white,
          primaryContainer: isDark
              ? AppColors.accentDeep
              : AppColors.accentLight,
          onPrimaryContainer: isDark ? Colors.white : const Color(0xFF06303B),
          secondary: AppColors.gold,
          onSecondary: Colors.black,
          error: AppColors.danger,
          surface: pal.surface,
          onSurface: pal.textPrimary,
          onSurfaceVariant: pal.textSecondary,
          surfaceContainerLowest: pal.background,
          surfaceContainerLow: pal.surface,
          surfaceContainer: pal.surfaceHigh,
          surfaceContainerHigh: pal.surfaceHigh,
          surfaceContainerHighest: pal.surfaceHighest,
          outline: pal.outline,
          outlineVariant: pal.outline.withValues(alpha: 0.5),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: resolved,
      extensions: <ThemeExtension<dynamic>>[pal],
      scaffoldBackgroundColor: pal.background,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,

      // ── Tipografía ────────────────────────────────────────────────────
      // Se usa la fuente del sistema (Roboto/SF/Segoe) para no depender de
      // descargas en tiempo de ejecución: funciona igual en las 6 plataformas.
      typography: Typography.material2021(
        platform: defaultTargetPlatform,
        colorScheme: resolved,
      ),
      textTheme: _textTheme(resolved, isDark).apply(
        displayColor: isDark ? AppColors.textPrimary : Colors.black,
        bodyColor: isDark ? AppColors.textPrimary : Colors.black87,
      ),

      // ── Barra de aplicación ───────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: isDark ? AppColors.textPrimary : Colors.black87,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: isDark ? AppColors.textPrimary : Colors.black87,
        ),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      // ── Componentes ───────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: pal.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(color: pal.outline.withValues(alpha: 0.35)),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: pal.surfaceHigh,
        selectedColor: AppColors.accentDeep,
        side: BorderSide(color: pal.outline.withValues(alpha: 0.5)),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.textSecondary : Colors.black87,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceHigh : const Color(0xFFF2F2F7),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: _inputBorder(
          isDark ? AppColors.outline : const Color(0xFFDCDCE4),
        ),
        enabledBorder: _inputBorder(
          isDark ? AppColors.outline : const Color(0xFFDCDCE4),
        ),
        focusedBorder: _inputBorder(AppColors.crimson, width: 1.6),
        errorBorder: _inputBorder(AppColors.danger),
        focusedErrorBorder: _inputBorder(AppColors.danger, width: 1.6),
        hintStyle: TextStyle(
          color: isDark ? AppColors.textDisabled : Colors.black38,
        ),
        labelStyle: TextStyle(
          color: isDark ? AppColors.textSecondary : Colors.black54,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.crimson,
          foregroundColor: Colors.white,
          disabledBackgroundColor: isDark
              ? AppColors.surfaceHighest
              : const Color(0xFFDCDCE4),
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: pal.textPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          side: BorderSide(color: pal.outline),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.crimson,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: isDark ? AppColors.textPrimary : Colors.black87,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: pal.surface.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.crimson.withValues(alpha: 0.18),
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
          (Set<WidgetState> states) => TextStyle(
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.crimson
                : (isDark ? AppColors.textSecondary : Colors.black54),
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
          (Set<WidgetState> states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? AppColors.crimson
                : (isDark ? AppColors.textSecondary : Colors.black54),
          ),
        ),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? AppColors.surface : Colors.white,
        indicatorColor: AppColors.crimson.withValues(alpha: 0.18),
        selectedIconTheme: const IconThemeData(
          color: AppColors.crimson,
          size: 24,
        ),
        unselectedIconTheme: IconThemeData(
          color: isDark ? AppColors.textSecondary : Colors.black54,
          size: 24,
        ),
        selectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.crimson,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.textSecondary : Colors.black54,
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.crimson,
        unselectedLabelColor: isDark ? AppColors.textSecondary : Colors.black54,
        indicatorColor: AppColors.crimson,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.outline : const Color(0xFFE4E4EC),
        thickness: 1,
        space: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.surfaceHighest : Colors.black87,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius - 2),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.surfaceHigh : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius + 4),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.surfaceHigh : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.crimson,
        linearTrackColor: AppColors.surfaceHighest,
        circularTrackColor: Colors.transparent,
      ),

      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll<Color>(
          isDark ? AppColors.outline : const Color(0xFFC8C8D4),
        ),
        thickness: const WidgetStatePropertyAll<double>(6),
        radius: const Radius.circular(3),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide(color: color, width: width),
      );

  static TextTheme _textTheme(ColorScheme scheme, bool isDark) {
    final Color headline = isDark ? AppColors.textPrimary : Colors.black87;
    final Color body = isDark ? AppColors.textSecondary : Colors.black54;

    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 44,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.4,
        color: headline,
      ),
      displayMedium: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.1,
        color: headline,
      ),
      headlineLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: headline,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: headline,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: headline,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: headline,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: headline,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: headline,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: body),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: body),
      bodySmall: TextStyle(fontSize: 12.5, height: 1.45, color: body),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: headline,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: body,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: body,
      ),
    );
  }
}

/// Extensión de acceso rápido al tema desde cualquier `BuildContext`.
extension AppThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;

  /// Colores dependientes del tema (superficies y textos).
  AppPal get pal => Theme.of(this).extension<AppPal>()!;
}
