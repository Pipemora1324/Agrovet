// La CNN de la ubre en la app debe dar lo mismo que el TFLite exportado por ml/ sobre los patrones
// sintéticos de ml/models/udder_cnn_vectors.json (no son fotos: imágenes definidas por fórmula).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:agrovet/core/config.dart';
import 'package:agrovet/data/ml/udder_model.dart';
import 'package:agrovet/domain/udder_triage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Misma fórmula que synthetic_pattern() en ml/src/train_udder_public.py.
Float32List syntheticPattern(int kind, {int size = 224}) {
  final rgb = Float32List(size * size * 3);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      late final List<int> c;
      switch (kind) {
        case 0:
          c = [(x * 255) ~/ (size - 1), (y * 255) ~/ (size - 1), ((x + y) * 255) ~/ (2 * (size - 1))];
        case 1:
          c = [(x * 7 + y * 3) % 256, (x * 5 + y * 11) % 256, (x * 13 + y * 2) % 256];
        case 2:
          final checker = ((x ~/ 28 + y ~/ 28) % 2) * 200 + 30;
          c = [checker, checker ~/ 2 + 60, 255 - checker];
        default:
          final r = math.sqrt(math.pow(x - size / 2, 2) + math.pow(y - size / 2, 2));
          final ring = (math.cos(r / 6) * 100 + 128).toInt();
          c = [(ring + 40).clamp(0, 255), ring, (ring - 40).clamp(0, 255)];
      }
      final i = (y * size + x) * 3;
      rgb[i] = c[0].toDouble();
      rgb[i + 1] = c[1].toDouble();
      rgb[i + 2] = c[2].toDouble();
    }
  }
  return rgb;
}

void main() {
  String lf(String path) => File(path).readAsStringSync().replaceAll('\r\n', '\n');
  final config = UdderModelConfig.fromJson(
    jsonDecode(File('assets/model/udder_cnn_config.json').readAsStringSync()) as Map<String, dynamic>,
  );

  test('el triaje visual está apagado por defecto', () {
    expect(AppConfig.udderTriageEnabled, isFalse);
    expect(config.enabledByDefault, isFalse);
    expect(config.disclaimer, contains('no es diagnóstico'));
  });

  test('el modelo y la configuración de la app son los mismos que exportó ml/', () {
    expect(File('assets/model/${config.modelFile}').readAsBytesSync(),
        File('../ml/models/${config.modelFile}').readAsBytesSync());
    expect(lf('assets/model/udder_cnn_config.json'), lf('../ml/models/udder_cnn_config.json'));
  });

  test('RGBA a RGB descarta el canal alfa', () {
    expect(rgbaToRgb(Uint8List.fromList([1, 2, 3, 255, 4, 5, 6, 0])), [1, 2, 3, 4, 5, 6]);
  });

  group('probabilidad del modelo TFLite', () {
    final vectors = jsonDecode(File('../ml/models/udder_cnn_vectors.json').readAsStringSync()) as Map<String, dynamic>;
    late UdderModel model;

    setUpAll(() => model = UdderModel.fromBytes(File('assets/model/${config.modelFile}').readAsBytesSync(), config));
    tearDownAll(() => model.close());

    for (final testCase in (vectors['cases'] as List).cast<Map<String, dynamic>>()) {
      test('patrón ${testCase['pattern']} igual al TFLite de Python', () {
        final result = model.predict(syntheticPattern(testCase['pattern'] as int));
        expect(result.probability, closeTo((testCase['tflite'] as num).toDouble(), 1e-4));
        expect(result.probability, closeTo((testCase['keras'] as num).toDouble(), (vectors['tolerance'] as num).toDouble()));
      });
    }

    test('rechaza una entrada del tamaño equivocado', () {
      expect(() => model.predict(Float32List(10)), throwsArgumentError);
    });
  });
}
