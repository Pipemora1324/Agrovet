import 'package:flutter/material.dart';

import '../domain/entities.dart';

/// Tema de campo: alto contraste para leer a pleno sol, texto grande y botones amplios.
class AppTheme {
  static const primary = Color(0xFF1B5E20);
  static const background = Color(0xFFF3F5EF);
  static const ink = Color(0xFF111611);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      onPrimary: Colors.white,
      secondary: const Color(0xFF6D4C1F),
      surface: Colors.white,
      onSurface: ink,
      error: const Color(0xFFB3261E),
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: background);
    final text = base.textTheme.apply(bodyColor: ink, displayColor: ink).copyWith(
          bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 18, height: 1.35, color: ink),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 16, height: 1.35, color: ink),
          titleLarge: base.textTheme.titleLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.w700, color: ink),
          titleMedium: base.textTheme.titleMedium?.copyWith(fontSize: 19, fontWeight: FontWeight.w700, color: ink),
          labelLarge: base.textTheme.labelLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
        );
    const radius = BorderRadius.all(Radius.circular(16));
    return base.copyWith(
      textTheme: text,
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: Color(0xFFD5DBCF))),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 64),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          shape: const RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 64),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 2),
          textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          shape: const RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: primary,
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        extendedTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        labelStyle: TextStyle(fontSize: 18, color: Color(0xFF3B4639)),
        floatingLabelStyle: TextStyle(fontSize: 18, color: primary, fontWeight: FontWeight.w700),
        helperStyle: TextStyle(fontSize: 14, color: Color(0xFF3B4639)),
        errorStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        border: OutlineInputBorder(borderRadius: radius),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: Color(0xFF59654F), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: primary, width: 2.5),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: Color(0xFF3B4639), width: 2),
        visualDensity: VisualDensity.standard,
        fillColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? primary : Colors.white),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: TextStyle(fontSize: 17, color: Colors.white),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }
}

/// Colores del semáforo con texto legible encima de cada uno.
extension RiskColors on RiskLevel {
  Color get color => switch (this) {
        RiskLevel.green => const Color(0xFF2E7D32),
        RiskLevel.yellow => const Color(0xFFF9A825),
        RiskLevel.red => const Color(0xFFC62828),
      };

  Color get onColor => this == RiskLevel.yellow ? const Color(0xFF1A1400) : Colors.white;

  IconData get icon => switch (this) {
        RiskLevel.green => Icons.check_circle,
        RiskLevel.yellow => Icons.visibility,
        RiskLevel.red => Icons.warning_rounded,
      };
}
