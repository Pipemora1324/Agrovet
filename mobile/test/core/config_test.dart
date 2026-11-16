import 'package:agrovet/core/config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const host = 'agrovet.example.co';

void main() {
  test('sin --dart-define=API_BASE_URL la app no arranca y explica cómo compilarla', () {
    expect(AppConfig.problemFor('', release: false), contains('--dart-define=API_BASE_URL'));
    expect(AppConfig.problemFor('', release: true), isNotNull);
  });

  test('la compilación de demostración arranca sin servidor, pero no acepta una dirección insegura', () {
    expect(AppConfig.problemFor('', release: true, demoBuild: true), isNull);
    expect(AppConfig.problemFor('http://$host', release: true, demoBuild: true), contains('HTTPS'));
    expect(AppConfig.problemFor('https://$host', release: true, demoBuild: true), isNull);
  });

  test('la demostración está apagada por defecto fuera de debug', () {
    // Las pruebas corren en debug: la demostración existe por ser debug, no por la bandera
    expect(AppConfig.demoBuild, isFalse);
    expect(AppConfig.withoutServer, isFalse);
    expect(AppConfig.isDebugBuild, kDebugMode);
    expect(AppConfig.demoAvailable, isTrue);
  });

  test('en release solo HTTPS', () {
    expect(AppConfig.problemFor('https://$host', release: true), isNull);
    expect(AppConfig.problemFor('http://$host', release: true), contains('HTTPS'));
    expect(AppConfig.problemFor('http://10.0.2.2:8080', release: true), contains('HTTPS'));
  });

  test('en debug HTTP solo hacia el equipo de desarrollo', () {
    for (final url in ['http://10.0.2.2:8080', 'http://localhost:8080', 'http://127.0.0.1:8080']) {
      expect(AppConfig.problemFor(url, release: false), isNull, reason: url);
    }
    expect(AppConfig.problemFor('http://192.168.1.20:8080', release: false), isNotNull);
    expect(AppConfig.problemFor('https://$host', release: false), isNull);
    expect(AppConfig.problemFor('no es una url', release: false), isNotNull);
  });
}
