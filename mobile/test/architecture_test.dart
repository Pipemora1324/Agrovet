import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regla de arquitectura: los valores visuales viven solo en lib/core/theme.dart, para poder
/// rehacer el diseño cambiando un único archivo.
void main() {
  test('ningún archivo fuera de theme.dart define colores ni tipografía a mano', () {
    final forbidden = RegExp(r'Color\(0x|(?<!App)Colors\.|fontSize:|FontWeight\.|fontFamily:');
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.endsWith('lib/core/theme.dart') || path.endsWith('.g.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (forbidden.hasMatch(lines[i])) offenders.add('$path:${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(offenders, isEmpty, reason: 'Mueva estos valores a lib/core/theme.dart:\n${offenders.join('\n')}');
  });
}
