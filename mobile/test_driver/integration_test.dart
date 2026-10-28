import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Guarda las capturas de las pruebas de integración en build/screenshots (o en SCREENSHOT_DIR).
Future<void> main() => integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        final dir = Directory(Platform.environment['SCREENSHOT_DIR'] ?? 'build/screenshots')
          ..createSync(recursive: true);
        File('${dir.path}/$name.png').writeAsBytesSync(bytes);
        return true;
      },
    );
