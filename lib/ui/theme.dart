import 'package:material_ui/material_ui.dart';

/// A deliberately quiet palette. The content is the Qur'an; the interface
/// should recede. One accent colour, generous spacing, no gradients.
class AppColors {
  static const seedLight = Color(0xFF1F6F5C);
  static const seedDark = Color(0xFF4FB79A);

  static const paper = Color(0xFFFBF8F3); // warm off-white
  static const ink = Color(0xFF0E1412); // near-black with a green cast
  static const inkSurface = Color(0xFF18201D);
  static const gold = Color(0xFFC9A227);
  static const goldDark = Color(0xFFD9BC63);
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;

  final scheme = ColorScheme.fromSeed(
    seedColor: dark ? AppColors.seedDark : AppColors.seedLight,
    brightness: brightness,
  ).copyWith(
    surface: dark ? AppColors.ink : AppColors.paper,
    secondary: dark ? AppColors.goldDark : AppColors.gold,
  );

  const uiFont = 'Tajawal';

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: uiFont,
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: uiFont,
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    cardTheme: CardThemeData(
      color: dark ? AppColors.inkSurface : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 3,
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.primary.withValues(alpha: 0.18),
      thumbColor: scheme.primary,
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.onSurface.withValues(alpha: 0.07),
      space: 1,
      thickness: 1,
    ),
    textTheme: base.textTheme.copyWith(
      // Surah names get the classical naskh face.
      titleLarge: TextStyle(
        fontFamily: 'Amiri',
        fontSize: 26,
        height: 1.6,
        color: scheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Amiri',
        fontSize: 21,
        height: 1.6,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
  );
}
