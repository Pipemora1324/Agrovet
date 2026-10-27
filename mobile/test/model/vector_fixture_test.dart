import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/test_vectors_fixture.dart';
import '../../tool/generate_vector_fixture.dart';

void main() {
  test('el fixture de la prueba en dispositivo está al día con ml/models/test_vectors.json', () {
    final json = File('../ml/models/test_vectors.json').readAsStringSync();
    expect(testVectorsJson, json);
    expect(File('integration_test/test_vectors_fixture.dart').readAsStringSync(), fixtureSource(json),
        reason: 'Ejecute: dart run tool/generate_vector_fixture.dart');
  });
}
