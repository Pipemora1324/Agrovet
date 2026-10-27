// Genera integration_test/test_vectors_fixture.dart a partir de ml/models/test_vectors.json,
// para correr la prueba de vectores en el emulador o el celular (que no pueden leer ml/).
// Uso: dart run tool/generate_vector_fixture.dart
import 'dart:io';

void main() {
  final json = File('../ml/models/test_vectors.json').readAsStringSync();
  File('integration_test/test_vectors_fixture.dart').writeAsStringSync(fixtureSource(json));
  stdout.writeln('integration_test/test_vectors_fixture.dart actualizado');
}

String fixtureSource(String json) => '''
// Generado por tool/generate_vector_fixture.dart a partir de ml/models/test_vectors.json. No editar a mano.
// ignore_for_file: lines_longer_than_80_chars
const testVectorsJson = r\'\'\'
$json\'\'\';
''';
