import 'package:agrovet/core/theme.dart';
import 'package:agrovet/domain/entities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reglas de legibilidad en campo: textos desde 16 sp, controles de 56 dp y Figtree embebida.
void main() {
  final theme = AppTheme.light();

  test('ningún estilo de texto baja de 16 sp', () {
    final t = theme.textTheme;
    final styles = {
      'displaySmall': t.displaySmall, 'headlineMedium': t.headlineMedium, 'headlineSmall': t.headlineSmall,
      'titleLarge': t.titleLarge, 'titleMedium': t.titleMedium, 'titleSmall': t.titleSmall,
      'bodyLarge': t.bodyLarge, 'bodyMedium': t.bodyMedium, 'bodySmall': t.bodySmall,
      'labelLarge': t.labelLarge, 'labelMedium': t.labelMedium, 'labelSmall': t.labelSmall,
      'axis': t.axis, 'chip': t.chip, 'banner': t.banner,
    };
    for (final entry in styles.entries) {
      expect(entry.value!.fontSize, greaterThanOrEqualTo(16), reason: entry.key);
      expect(entry.value!.fontFamily, AppTheme.fontFamily, reason: entry.key);
    }
  });

  test('botones de 56 dp de alto y objetivo táctil de 48 dp', () {
    Size? min(ButtonStyle? style) => style?.minimumSize?.resolve({});
    expect(min(theme.filledButtonTheme.style)!.height, AppSizes.control);
    expect(min(theme.outlinedButtonTheme.style)!.height, AppSizes.control);
    expect(min(theme.textButtonTheme.style)!.height, greaterThanOrEqualTo(AppSizes.touch));
    expect(min(theme.iconButtonTheme.style)!.width, greaterThanOrEqualTo(AppSizes.touch));
    expect(theme.inputDecorationTheme.constraints!.minHeight, AppSizes.control);
  });

  test('paleta del semáforo con fondo y texto propios', () {
    expect(AppColors.primary, const Color(0xFF1F6B45));
    expect(RiskLevel.red.color, const Color(0xFFB3261E));
    expect(RiskLevel.red.surface, const Color(0xFFFBDAD7));
    expect(RiskLevel.yellow.textColor, const Color(0xFF6B4500));
    expect(RiskLevel.green.surface, const Color(0xFFDDF3E4));
  });
}
