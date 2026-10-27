import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/test_vectors_fixture.dart';
import '../../tool/generate_vector_fixture.dart';

void main() {
  // Se ignoran los fines de línea: git puede escribir CRLF en Windows y LF en Linux
  String lf(String text) => text.replaceAll('\r\n', '\n');

  test('el fixture de la prueba en dispositivo está al día con ml/models/test_vectors.json', () {
    final json = lf(File('../ml/models/test_vectors.json').readAsStringSync());
    expect(lf(testVectorsJson), json);
    expect(lf(File('integration_test/test_vectors_fixture.dart').readAsStringSync()), lf(fixtureSource(json)),
        reason: 'Ejecute: dart run tool/generate_vector_fixture.dart');
  });
}
