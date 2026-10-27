// Prueba bloqueante: la app debe reproducir exactamente lo que calcula Python
// (ml/models/test_vectors.json), tanto la normalización como la probabilidad del modelo.
import 'dart:convert';
import 'dart:io';

import 'package:agrovet/data/ml/risk_model.dart';
import 'package:agrovet/domain/model_config.dart';
import 'package:agrovet/domain/preprocessor.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final vectors = jsonDecode(File('../ml/models/test_vectors.json').readAsStringSync()) as Map<String, dynamic>;
  final config = ModelConfig.fromJson(
    jsonDecode(File('assets/model/model_config.json').readAsStringSync()) as Map<String, dynamic>,
  );
  final preprocessor = Preprocessor(config);
  final cases = (vectors['cases'] as List).cast<Map<String, dynamic>>();
  final tolerance = (vectors['tolerance'] as num).toDouble();

  List<List<double?>> rawWindow(Map<String, dynamic> testCase) => [
        for (final day in testCase['raw_window'] as List)
          [for (final value in day as List) value == null ? null : (value as num).toDouble()],
      ];

  test('el modelo y la configuración de la app son los mismos que exportó ml/', () {
    final appModel = File('assets/model/${config.modelFile}').readAsBytesSync();
    final digest = sha256.convert(appModel).toString();
    expect(digest, vectors['tflite_sha256']);
    expect(File('assets/model/model_config.json').readAsStringSync(),
        File('../ml/models/model_config.json').readAsStringSync());
  });

  test('hay 8 casos de cuatro tipos', () {
    expect(cases, hasLength(8));
    expect(cases.map((c) => c['kind']).toSet(),
        {'healthy', 'subclinical', 'estrus', 'erroneous_record'});
  });

  for (final testCase in cases) {
    test('normalización igual a Python: ${testCase['id']}', () {
      final normalized = preprocessor.preprocess(rawWindow(testCase));
      expect(normalized, isNotNull);
      final expected = testCase['expected_normalized'] as List;
      for (var day = 0; day < expected.length; day++) {
        for (var col = 0; col < 3; col++) {
          expect(normalized![day][col], closeTo(((expected[day] as List)[col] as num).toDouble(), 1e-9),
              reason: 'día $day, variable $col');
        }
      }
    });
  }

  group('probabilidad del modelo TFLite', () {
    late RiskModel model;

    setUpAll(() {
      model = RiskModel.fromBytes(File('assets/model/${config.modelFile}').readAsBytesSync(), config);
    });

    tearDownAll(() => model.close());

    for (final testCase in cases) {
      test('igual a Python (tolerancia $tolerance): ${testCase['id']}', () {
        final probability = model.predict(preprocessor.preprocess(rawWindow(testCase))!);
        expect(probability, closeTo((testCase['expected_probability'] as num).toDouble(), tolerance));
        expect(config.riskLevelFor(probability).code.toLowerCase(), testCase['expected_color']);
      });
    }
  });
}
