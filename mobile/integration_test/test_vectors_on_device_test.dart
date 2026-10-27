// Corre en el emulador o el celular: el intérprete TFLite nativo de Android debe dar las mismas
// probabilidades que Python (ml/models/test_vectors.json) con tolerancia 1e-4.
// Uso: flutter test integration_test/test_vectors_on_device_test.dart -d <dispositivo>
import 'dart:convert';

import 'package:agrovet/data/ml/risk_model.dart';
import 'package:agrovet/domain/preprocessor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_vectors_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('el modelo del APK reproduce los 8 vectores de Python', (tester) async {
    final vectors = jsonDecode(testVectorsJson) as Map<String, dynamic>;
    final tolerance = (vectors['tolerance'] as num).toDouble();
    final model = await RiskModel.load();
    final preprocessor = Preprocessor(model.config);

    for (final testCase in (vectors['cases'] as List).cast<Map<String, dynamic>>()) {
      final raw = [
        for (final day in testCase['raw_window'] as List)
          [for (final v in day as List) v == null ? null : (v as num).toDouble()],
      ];
      final probability = model.predict(preprocessor.preprocess(raw)!);
      expect(probability, closeTo((testCase['expected_probability'] as num).toDouble(), tolerance),
          reason: testCase['id'] as String);
    }
    model.close();
  });
}
