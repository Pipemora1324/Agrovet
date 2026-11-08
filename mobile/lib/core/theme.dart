import 'package:flutter/material.dart';

import '../domain/entities.dart';

/// Único lugar con los valores visuales de la app: colores, tipografía, radios y estilos de los
/// componentes. Las pantallas usan los roles de Material 3 (colorScheme, textTheme) y los nombres de
/// este archivo; nunca escriben un color ni un tamaño de letra a mano. Para rediseñar la app basta
/// con cambiar este archivo.
class AppColors {
  AppColors._();

  // Marca
  static const primary = Color(0xFF1B5E20);
  static const onPrimary = Colors.white;
  static const secondary = Color(0xFF6D4C1F);
  static const background = Color(0xFFF3F5EF);
  static const surface = Colors.white;
  static const ink = Color(0xFF111611);
  static const inkMuted = Color(0xFF3B4639);
  static const outline = Color(0xFF59654F);
  static const outlineSoft = Color(0xFFC9D0C2);
  static const cardBorder = Color(0xFFD5DBCF);
  static const error = Color(0xFFB3261E);

  // Semáforo
  static const riskGreen = Color(0xFF2E7D32);
  static const riskYellow = Color(0xFFF9A825);
  static const riskRed = Color(0xFFC62828);
  static const onRiskYellow = Color(0xFF1A1400);
  static const riskNone = Color(0xFFE3E7DF);
  static const trafficLightBody = Color(0xFF1F2420);

  /// Texto "de advertencia" legible sobre fondo claro (el amarillo del semáforo no lo es).
  static const warningText = Color(0xFF7A5600);

  // Resaltados
  static const highlightSurface = Color(0xFFFFF3CD);
  static const highlightBorder = Color(0xFFB07A00);
  static const demoBanner = Color(0xFFFFE082);
  static const onDemoBanner = Color(0xFF3E2C00);
  static const notice = Color(0xFF263238);
  static const onNotice = Colors.white;
  static const info = Color(0xFF1565C0);
  static const infoSurface = Color(0xFFE3F2FD);

  // Gráficas del historial
  static const chartTemperature = Color(0xFFC62828);
  static const chartMilk = Color(0xFF1565C0);
  static const chartFeed = Color(0xFF6D4C1F);
}

class AppRadius {
  AppRadius._();

  static const small = 12.0;
  static const medium = 16.0;
  static const pill = 24.0;

  static const card = BorderRadius.all(Radius.circular(medium));
}

/// Estilos de texto con nombre propio, derivados del textTheme para no repetir tamaños.
extension AppTextStyles on TextTheme {
  /// Etiqueta en negrita de una fila "Campo: valor".
  TextStyle get fieldLabel => titleSmall!;

  /// Valor de una fila "Campo: valor".
  TextStyle get fieldValue => titleSmall!.copyWith(fontWeight: FontWeight.w400);

  /// Número grande en los campos de medición.
  TextStyle get numberInput => titleLarge!.copyWith(fontSize: 22);

  /// Unidad al lado del número (°C, L, kg).
  TextStyle get numberUnit => titleMedium!.copyWith(fontSize: 20);

  /// Texto de las fichas del semáforo y etiquetas pequeñas.
  TextStyle get chip => labelMedium!;

  /// Texto de una franja de aviso (por ejemplo, "Datos de demostración").
  TextStyle get banner => labelMedium!.copyWith(fontSize: 16);

  /// Párrafo destacado.
  TextStyle get emphasis => bodyLarge!.copyWith(fontWeight: FontWeight.w600);

  /// Rótulos de los ejes de las gráficas.
  TextStyle get axis => labelSmall!;

  /// Mensaje de error de un formulario.
  TextStyle get formError => titleSmall!.copyWith(color: AppColors.error);

  /// Código de verificación (dígitos grandes y espaciados).
  TextStyle get code => headlineMedium!.copyWith(letterSpacing: 12, fontWeight: FontWeight.w800);
}

/// Tema de campo: alto contraste para leer a pleno sol, texto grande y botones amplios.
class AppTheme {
  AppTheme._();

  // Atajos que usan las pantallas antiguas; apuntan a la misma paleta
  static const primary = AppColors.primary;
  static const background = AppColors.background;
  static const ink = AppColors.ink;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkMuted,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineSoft,
      error: AppColors.error,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: AppColors.background);
    final t = base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
    final text = t.copyWith(
      headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      headlineSmall: t.headlineSmall?.copyWith(fontSize: 26, fontWeight: FontWeight.w800),
      titleLarge: t.titleLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
      titleMedium: t.titleMedium?.copyWith(fontSize: 19, fontWeight: FontWeight.w700),
      titleSmall: t.titleSmall?.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
      bodyLarge: t.bodyLarge?.copyWith(fontSize: 18, height: 1.35),
      bodyMedium: t.bodyMedium?.copyWith(fontSize: 16, height: 1.35),
      bodySmall: t.bodySmall?.copyWith(fontSize: 14, color: AppColors.inkMuted),
      labelLarge: t.labelLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      labelMedium: t.labelMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w800),
      labelSmall: t.labelSmall?.copyWith(fontSize: 13, color: AppColors.ink),
    );
    const radius = AppRadius.card;
    const buttonText = TextStyle(fontSize: 19, fontWeight: FontWeight.w700);
    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontSize: 22, color: AppColors.onPrimary),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: AppColors.cardBorder)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 64),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: buttonText,
          shape: const RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 64),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 2),
          textStyle: buttonText,
          shape: const RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(64, 56),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surface,
        labelStyle: text.titleSmall,
        secondaryLabelStyle: text.titleSmall?.copyWith(color: AppColors.onPrimary),
        checkmarkColor: AppColors.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        extendedTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        labelStyle: TextStyle(fontSize: 18, color: AppColors.inkMuted),
        floatingLabelStyle: TextStyle(fontSize: 18, color: AppColors.primary, fontWeight: FontWeight.w700),
        helperStyle: TextStyle(fontSize: 14, color: AppColors.inkMuted),
        helperMaxLines: 3,
        errorStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        errorMaxLines: 3,
        border: OutlineInputBorder(borderRadius: radius),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.outline, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.primary, width: 2.5),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: AppColors.inkMuted, width: 2),
        visualDensity: VisualDensity.standard,
        fillColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? AppColors.primary : AppColors.surface),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? AppColors.onPrimary : AppColors.outline),
        trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? AppColors.primary : AppColors.riskNone),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.primary,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodyMedium,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.cardBorder),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: TextStyle(fontSize: 17, color: Colors.white),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(linearTrackColor: AppColors.riskNone),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }
}

/// Colores del semáforo con texto legible encima de cada uno.
extension RiskColors on RiskLevel {
  Color get color => switch (this) {
        RiskLevel.green => AppColors.riskGreen,
        RiskLevel.yellow => AppColors.riskYellow,
        RiskLevel.red => AppColors.riskRed,
      };

  Color get onColor => this == RiskLevel.yellow ? AppColors.onRiskYellow : Colors.white;

  /// Color para escribir el nivel sobre fondo claro (el amarillo puro no se lee).
  Color get textColor => this == RiskLevel.yellow ? AppColors.warningText : color;

  IconData get icon => switch (this) {
        RiskLevel.green => Icons.check_circle,
        RiskLevel.yellow => Icons.visibility,
        RiskLevel.red => Icons.warning_rounded,
      };
}
