// El clasificador experimental de leche en la app debe preparar la foto igual que ml/ y dar lo mismo
// que el TFLite de Python (ml/models/milk_cnn_vectors.json, fotos en ml/tests/fixtures/milk/).
// Estos pozos estuvieron en el entrenamiento del modelo: aquí se compara el preprocesamiento, no la
// exactitud.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agrovet/data/ml/milk_model.dart';
import 'package:agrovet/domain/milk_check.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixtures = '../ml/tests/fixtures/milk';

/// Misma fórmula que synthetic_photo() en ml/src/export_milk_vectors.py, en RGBA.
DecodedImage syntheticPhoto(int width, int height) {
  final rgba = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      rgba[i] = (x * 7 + y * 3) % 256;
      rgba[i + 1] = (x * 5 + y * 11) % 256;
      rgba[i + 2] = (x * 13 + y * 2) % 256;
      rgba[i + 3] = 255;
    }
  }
  return DecodedImage(width, height, rgba);
}

Future<Uint8List> pythonCrop(String name) async {
  final image = await decodeRgba(File('$_fixtures/$name').readAsBytesSync());
  final rgba = image.rgba;
  return Uint8List.fromList([
    for (var i = 0; i < rgba.length; i += 4) ...[rgba[i], rgba[i + 1], rgba[i + 2]],
  ]);
}

CropBox box(List<dynamic> values) =>
    CropBox(values[0] as int, values[1] as int, values[2] as int, values[3] as int);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String lf(String path) => File(path).readAsStringSync().replaceAll('\r\n', '\n');
  final vectors = jsonDecode(File('../ml/models/milk_cnn_vectors.json').readAsStringSync()) as Map<String, dynamic>;
  final config = MilkModelConfig.fromJson(
    jsonDecode(File('assets/model/milk_cnn_config.json').readAsStringSync()) as Map<String, dynamic>,
  );

  test('el modelo y la configuración son los que exportó ml/, con su aviso fijo', () {
    expect(File('assets/model/${config.modelFile}').readAsBytesSync(),
        File('../ml/models/${config.modelFile}').readAsBytesSync());
    expect(lf('assets/model/milk_cnn_config.json'), lf('../ml/models/milk_cnn_config.json'));
    expect(config.inputSize, 160);
    expect(config.onlyDemoBuild, isTrue);
    expect(config.disclaimer, MilkCheckResult.disclaimer);
  });

  group('recorte y redimensionado iguales a Pillow', () {
    final synthetic = vectors['synthetic'] as Map<String, dynamic>;
    final size = (synthetic['size'] as List).cast<int>();

    for (final c in (synthetic['cases'] as List).cast<Map<String, dynamic>>()) {
      test('imagen sintética, caja ${c['box']}: mismos píxeles', () async {
        final mine = milkInput(syntheticPhoto(size[0], size[1]), box(c['box'] as List), 160);
        expect(mine, await pythonCrop(c['pythonCrop'] as String));
      });
    }

    test('con el mismo tamaño de entrada y salida no cambia nada', () {
      final rgb = Uint8List.fromList(List.generate(4 * 3 * 3, (i) => (i * 37) % 256));
      expect(resizeBilinear(rgb, 4, 3, 4, 3), rgb);
    });

    test('una caja que se sale de la foto se ajusta a la foto', () {
      expect(const CropBox(-5, -2, 900, 400).clampTo(640, 360), const CropBox(0, 0, 640, 360));
      expect(const CropBox(700, 10, 800, 5).clampTo(640, 360), const CropBox(639, 10, 640, 11));
    });
  });

  group('fotos del dataset', () {
    late MilkModel model;
    setUpAll(() => model = MilkModel.fromBytes(File('assets/model/${config.modelFile}').readAsBytesSync(), config));
    tearDownAll(() => model.close());

    for (final c in (vectors['cases'] as List).cast<Map<String, dynamic>>()) {
      test('${c['photo']} (${c['grade']}): mismo recorte y misma probabilidad que Python', () async {
        final photo = await decodeRgba(File('$_fixtures/${c['photo']}').readAsBytesSync());
        expect([photo.width, photo.height], c['imageSize']);
        final mine = milkInput(photo, box(c['box'] as List), config.inputSize);
        final python = await pythonCrop(c['pythonCrop'] as String);

        // La única diferencia posible es el decodificador de JPEG (Skia frente a libjpeg de Pillow)
        var total = 0, worst = 0;
        for (var i = 0; i < mine.length; i++) {
          final d = (mine[i] - python[i]).abs();
          total += d;
          if (d > worst) worst = d;
        }
        final mean = total / mine.length;
        final result = model.predict(mine);
        final expected = (c['tflite'] as num).toDouble();
        // ignore: avoid_print
        print('${c['photo']}: diferencia media ${mean.toStringAsFixed(3)}, máxima $worst; '
            'probabilidad app ${result.probability.toStringAsFixed(6)} / Python $expected');

        expect(mean, lessThan(1.0));
        expect(model.predict(python).probability, closeTo(expected, 1e-4));
        expect(result.probability, closeTo(expected, 1e-3));
        expect(result.abnormal, expected >= (vectors['threshold'] as num));
      });
    }

    test('rechaza una entrada del tamaño equivocado', () {
      expect(() => model.predict(Uint8List(10)), throwsArgumentError);
    });
  });

  test('resultado: etiqueta, porcentaje y umbral', () {
    expect(const MilkCheckResult(0.73, 0.5).label, 'Anormal');
    expect(const MilkCheckResult(0.73, 0.5).percent, 73);
    expect(const MilkCheckResult(0.5, 0.5).abnormal, isTrue);
    expect(const MilkCheckResult(0.12, 0.5).label, 'Normal');
  });
}
