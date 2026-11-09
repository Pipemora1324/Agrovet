import 'package:agrovet/core/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
