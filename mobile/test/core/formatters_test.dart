import 'package:agrovet/core/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('plainAssistantText', () {
    test('quita el Markdown que devolvió Gemini en la prueba del emulador', () {
      const raw = 'Para identificar señales de mastitis, observe lo siguiente:\n\n'
          '*   **Cambios en la leche:** Revise si hay grumos.\n'
          '*   **Estado de la ubre:** Fíjese si está caliente.\n\n\n'
          'Dado que su vaca presenta síntomas, **llame a su veterinario de confianza cuanto antes**.';
      expect(
        plainAssistantText(raw),
        'Para identificar señales de mastitis, observe lo siguiente:\n\n'
        '• Cambios en la leche: Revise si hay grumos.\n'
        '• Estado de la ubre: Fíjese si está caliente.\n\n'
        'Dado que su vaca presenta síntomas, llame a su veterinario de confianza cuanto antes.',
      );
    });

    test('quita títulos y respeta guiones y texto sin formato', () {
      expect(plainAssistantText('## Qué revisar\n- Ubre\n- Leche'), 'Qué revisar\n• Ubre\n• Leche');
      expect(plainAssistantText('Temperatura de 39,5 °C - revise'), 'Temperatura de 39,5 °C - revise');
      expect(plainAssistantText('2 * 3 no es viñeta'), '2 * 3 no es viñeta');
    });
  });

  test('joinSpanish une con comas y "y"', () {
    expect(joinSpanish([]), '');
    expect(joinSpanish(['leche']), 'leche');
    expect(joinSpanish(['temperatura', 'leche', 'alimento']), 'temperatura, leche y alimento');
  });

  group('formatElapsedSince', () {
    final now = DateTime(2026, 11, 9, 12);

    test('indica cuando todavía no hubo sincronización', () {
      expect(formatElapsedSince(null, now: now), 'Sin sincronizar aún');
    });

    test('usa unidades breves y claras', () {
      expect(formatElapsedSince(now, now: now), 'hace un momento');
      expect(
        formatElapsedSince(now.subtract(const Duration(minutes: 8)), now: now),
        'hace 8 min',
      );
      expect(
        formatElapsedSince(now.subtract(const Duration(hours: 1)), now: now),
        'hace 1 hora',
      );
      expect(
        formatElapsedSince(now.subtract(const Duration(hours: 3)), now: now),
        'hace 3 horas',
      );
      expect(
        formatElapsedSince(now.subtract(const Duration(days: 1)), now: now),
        'hace 1 día',
      );
      expect(
        formatElapsedSince(now.subtract(const Duration(days: 4)), now: now),
        'hace 4 días',
      );
    });

    test('una hora futura se muestra como reciente', () {
      expect(
        formatElapsedSince(now.add(const Duration(hours: 1)), now: now),
        'hace un momento',
      );
    });
  });
}
