import 'package:flutter/material.dart';

import '../domain/entities.dart';

/// Único lugar con los valores visuales de la app: colores, tipografía, radios, medidas, movimiento
/// y estilos de los componentes. Las pantallas usan los roles de Material 3 (colorScheme, textTheme)
/// y los nombres de este archivo; nunca escriben un color ni un tamaño de letra a mano. Para
/// rediseñar la app basta con cambiar este archivo.
class AppColors {
  AppColors._();

  // Marca
  static const primary = Color(0xFF1F6B45);
  static const primaryDark = Color(0xFF175A38);
  static const onPrimary = Colors.white;
  static const sun = Color(0xFFF6D774);
  static const onSun = Color(0xFF3A2E00);
  static const secondary = primaryDark;
  static const background = Color(0xFFF2F5EE);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF16251B);
  static const inkMuted = Color(0xFF4B5B50);
  static const outline = Color(0xFF7D8B80);
  static const outlineSoft = Color(0xFFD5DDD3);
  static const cardBorder = Color(0xFFD5DDD3);
  static const error = Color(0xFFB3261E);

  /// Verde muy claro para chips y burbujas propias.
  static const primarySoft = Color(0xFFDDF3E4);

  /// Formas decorativas sobre el verde (blanco translúcido).
  static const heroShape = Color(0x26FFFFFF);
  static const heroShapeStrong = Color(0x40FFFFFF);

  /// Brillo que recorre el botón principal.
  static const shine = Color(0x55FFFFFF);
  static const transparent = Color(0x00FFFFFF);

  // Semáforo: color, fondo y texto legible sobre el fondo
  static const riskRed = Color(0xFFB3261E);
  static const riskRedSurface = Color(0xFFFBDAD7);
  static const riskRedText = Color(0xFF7A1A14);
  static const riskYellow = Color(0xFFB7791F);
  static const riskYellowSurface = Color(0xFFFFF0C2);
  static const riskYellowText = Color(0xFF6B4500);
  static const riskGreen = Color(0xFF1F6B45);
  static const riskGreenSurface = Color(0xFFDDF3E4);
  static const riskGreenText = Color(0xFF14502F);
  static const onRiskYellow = Colors.white;
  static const riskNone = Color(0xFFE4E9E2);
  static const trafficLightBody = Color(0xFF16251B);

  /// Texto "de advertencia" legible sobre fondo claro.
  static const warningText = riskYellowText;

  // Resaltados
  static const highlightSurface = riskYellowSurface;
  static const highlightBorder = riskYellow;
  static const demoBanner = sun;
  static const onDemoBanner = onSun;
  static const notice = Color(0xFF16251B);
  static const onNotice = Colors.white;
  static const info = Color(0xFF1E5AA8);
  static const infoSurface = Color(0xFFE2ECF8);

  // Gráficas del historial
  static const chartTemperature = riskRed;
  static const chartMilk = info;
  static const chartFeed = riskYellow;
  static const chartGrid = Color(0xFFE4E9E2);
  static const chartBarTrack = Color(0xFFEDF1EA);
}

class AppRadius {
  AppRadius._();

  static const small = 14.0;
  static const medium = 16.0;
  static const large = 20.0;
  static const pill = 28.0;

  static const field = BorderRadius.all(Radius.circular(small));
  static const button = BorderRadius.all(Radius.circular(medium));
  static const card = BorderRadius.all(Radius.circular(large));
}

/// Medidas de los controles: alto de botones y campos, y objetivo táctil mínimo.
class AppSizes {
  AppSizes._();

  static const control = 56.0;
  static const touch = 48.0;

  /// Icono de las tarjetas y de los atajos.
  static const icon = 28.0;
}

/// Tiempos de las animaciones. Siempre pasan por Responsive.motion, que respeta la opción del
/// sistema de reducir el movimiento.
class AppMotion {
  AppMotion._();

  static const entrance = Duration(milliseconds: 550);
  static const stagger = Duration(milliseconds: 70);
  static const bars = Duration(milliseconds: 700);
  static const chart = Duration(milliseconds: 900);
  static const press = Duration(milliseconds: 110);
  static const pulse = Duration(milliseconds: 1400);
  static const shine = Duration(milliseconds: 2600);
  static const float = Duration(seconds: 6);
  static const page = Duration(milliseconds: 300);

  /// Escala de un elemento mientras se presiona.
  static const pressedScale = 0.97;

  /// Animaciones de ambiente que se repiten (pulso, brillo, formas flotantes). Las pruebas lo apagan
  /// para que pumpAndSettle termine; apagadas, hacen un solo ciclo.
  static bool ambient = true;
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
  TextStyle get banner => labelMedium!;

  /// Párrafo destacado.
  TextStyle get emphasis => bodyLarge!.copyWith(fontWeight: FontWeight.w600);

  /// Rótulos de los ejes de las gráficas.
  TextStyle get axis => labelSmall!;

  /// Mensaje de error de un formulario.
  TextStyle get formError => titleSmall!.copyWith(color: AppColors.error);

  /// Código de verificación (un dígito por casilla).
  TextStyle get code => headlineMedium!.copyWith(fontWeight: FontWeight.w800);

  /// Título grande del encabezado verde.
  TextStyle get heroTitle => displaySmall!.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.w800);

  /// Texto del encabezado verde.
  TextStyle get heroBody => bodyLarge!.copyWith(color: AppColors.onPrimary);

  /// Número del resumen (cuántas vacas en cada nivel) y del porcentaje.
  TextStyle get stat => headlineMedium!.copyWith(fontWeight: FontWeight.w800);

  /// Rótulo en mayúsculas pequeñas sobre una sección.
  TextStyle get overline => labelMedium!.copyWith(color: AppColors.inkMuted, letterSpacing: 0.6);
}

/// Tema de campo: alto contraste para leer a pleno sol, texto grande y controles amplios.
class AppTheme {
  AppTheme._();

  static const fontFamily = 'Figtree';

  // Atajos que usan las pantallas antiguas; apuntan a la misma paleta
  static const primary = AppColors.primary;
  static const background = AppColors.background;
  static const ink = AppColors.ink;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.riskGreenText,
      secondary: AppColors.primaryDark,
      tertiary: AppColors.sun,
      onTertiary: AppColors.onSun,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkMuted,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineSoft,
      error: AppColors.error,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.background,
    );
    final t = base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink, fontFamily: fontFamily);
    // Ningún texto baja de 16 sp
    final text = t.copyWith(
      displaySmall: t.displaySmall?.copyWith(fontSize: 34, height: 1.1, fontWeight: FontWeight.w800),
      headlineMedium: t.headlineMedium?.copyWith(fontSize: 28, fontWeight: FontWeight.w800),
      headlineSmall: t.headlineSmall?.copyWith(fontSize: 25, fontWeight: FontWeight.w800),
      titleLarge: t.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
      titleMedium: t.titleMedium?.copyWith(fontSize: 19, fontWeight: FontWeight.w700),
      titleSmall: t.titleSmall?.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
      bodyLarge: t.bodyLarge?.copyWith(fontSize: 18, height: 1.35),
      bodyMedium: t.bodyMedium?.copyWith(fontSize: 17, height: 1.35),
      bodySmall: t.bodySmall?.copyWith(fontSize: 16, color: AppColors.inkMuted),
      labelLarge: t.labelLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      labelMedium: t.labelMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      labelSmall: t.labelSmall?.copyWith(fontSize: 16, color: AppColors.inkMuted),
    );
    const buttonText = TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w700);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 22, vertical: 14);
    const buttonSize = Size(AppSizes.touch, AppSizes.control);
    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        surfaceTintColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card, side: BorderSide(color: AppColors.cardBorder)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          textStyle: buttonText,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.primary, width: 2),
          textStyle: buttonText,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(AppSizes.touch, AppSizes.touch),
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(AppSizes.touch, AppSizes.touch)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: buttonSize,
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surface,
        labelStyle: text.titleSmall,
        secondaryLabelStyle: text.titleSmall?.copyWith(color: AppColors.onPrimary),
        checkmarkColor: AppColors.onPrimary,
        side: const BorderSide(color: AppColors.cardBorder),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.field),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        extendedTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        constraints: BoxConstraints(minHeight: AppSizes.control),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(fontFamily: fontFamily, fontSize: 18, color: AppColors.inkMuted),
        floatingLabelStyle:
            TextStyle(fontFamily: fontFamily, fontSize: 18, color: AppColors.primary, fontWeight: FontWeight.w700),
        hintStyle: TextStyle(fontFamily: fontFamily, fontSize: 17, color: AppColors.inkMuted),
        helperStyle: TextStyle(fontFamily: fontFamily, fontSize: 16, color: AppColors.inkMuted),
        helperMaxLines: 3,
        errorStyle: TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w600),
        errorMaxLines: 3,
        border: OutlineInputBorder(borderRadius: AppRadius.field),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: BorderSide(color: AppColors.outline, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: BorderSide(color: AppColors.primary, width: 2.5),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: AppColors.inkMuted, width: 2),
        visualDensity: VisualDensity.standard,
        materialTapTargetSize: MaterialTapTargetSize.padded,
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
        minVerticalPadding: 12,
        minTileHeight: AppSizes.control,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodyMedium,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primarySoft,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => text.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.inkMuted)),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            size: AppSizes.icon,
            color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.inkMuted)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primarySoft,
        selectedIconTheme: const IconThemeData(size: AppSizes.icon, color: AppColors.primary),
        unselectedIconTheme: const IconThemeData(size: AppSizes.icon, color: AppColors.inkMuted),
        selectedLabelTextStyle: text.labelMedium?.copyWith(color: AppColors.primary),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(color: AppColors.inkMuted),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.cardBorder),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 17, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.field),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.riskNone,
        linearMinHeight: 8,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large))),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }
}

/// Estilos de botones para acciones destructivas (eliminar, dar de baja).
class AppButtonStyles {
  AppButtonStyles._();

  static ButtonStyle dangerFilled(BuildContext context) =>
      FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error);

  static ButtonStyle dangerOutlined(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return OutlinedButton.styleFrom(foregroundColor: error, side: BorderSide(color: error, width: 2));
  }

  /// Botón sobre el encabezado verde (fondo blanco, texto verde).
  static ButtonStyle onHero() => FilledButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primaryDark,
      );
}

/// Colores del semáforo con texto legible encima de cada uno.
extension RiskColors on RiskLevel {
  Color get color => switch (this) {
        RiskLevel.green => AppColors.riskGreen,
        RiskLevel.yellow => AppColors.riskYellow,
        RiskLevel.red => AppColors.riskRed,
      };

  Color get onColor => this == RiskLevel.yellow ? AppColors.onRiskYellow : Colors.white;

  /// Fondo claro del nivel (tarjetas, chips).
  Color get surface => switch (this) {
        RiskLevel.green => AppColors.riskGreenSurface,
        RiskLevel.yellow => AppColors.riskYellowSurface,
        RiskLevel.red => AppColors.riskRedSurface,
      };

  /// Color para escribir el nivel sobre fondo claro o sobre [surface].
  Color get textColor => switch (this) {
        RiskLevel.green => AppColors.riskGreenText,
        RiskLevel.yellow => AppColors.riskYellowText,
        RiskLevel.red => AppColors.riskRedText,
      };

  IconData get icon => switch (this) {
        RiskLevel.green => Icons.check_circle,
        RiskLevel.yellow => Icons.visibility,
        RiskLevel.red => Icons.warning_rounded,
      };
}
