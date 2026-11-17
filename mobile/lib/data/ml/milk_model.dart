import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_litert/flutter_litert.dart';

import '../../domain/milk_check.dart';

/// Clasificador experimental de pozo de leche (MobileNetV2 float16, ml/models/milk_cnn.tflite).
/// Entrada [1, 160, 160, 3] con RGB 0–255 en float (el modelo reescala por dentro); salida [1, 1].
/// Solo se empaqueta en el APK de demostración (ver android/app/build.gradle.kts).
class MilkModel {
  MilkModel._(this._interpreter, this.config);

  static const configAsset = 'assets/model/milk_cnn_config.json';

  final Interpreter _interpreter;
  final MilkModelConfig config;

  static Future<MilkModel> load({AssetBundle? bundle}) async {
    final assets = bundle ?? rootBundle;
    final config = MilkModelConfig.fromJson(
      jsonDecode(await assets.loadString(configAsset)) as Map<String, dynamic>,
    );
    final bytes = await assets.load('assets/model/${config.modelFile}');
    return fromBytes(bytes.buffer.asUint8List(), config);
  }

  static MilkModel fromBytes(Uint8List modelBytes, MilkModelConfig config) =>
      MilkModel._(Interpreter.fromBuffer(modelBytes), config);

  /// [rgb]: inputSize × inputSize × 3 valores 0–255 en orden fila, columna, canal.
  MilkCheckResult predict(Uint8List rgb) {
    final size = config.inputSize;
    if (rgb.length != size * size * 3) {
      throw ArgumentError('Se esperaban ${size * size * 3} valores y llegaron ${rgb.length}');
    }
    final input = Float32List.fromList([for (final v in rgb) v.toDouble()]).reshape<double>([1, size, size, 3]);
    final output = [
      [0.0],
    ];
    _interpreter.run(input, output);
    return MilkCheckResult(output[0][0], config.threshold);
  }

  void close() => _interpreter.close();
}

/// Foto decodificada en RGBA de 8 bits.
class DecodedImage {
  const DecodedImage(this.width, this.height, this.rgba);

  final int width;
  final int height;
  final Uint8List rgba;
}

/// Decodifica una foto (JPEG o PNG) con el decodificador del sistema.
Future<DecodedImage> decodeRgba(Uint8List encoded) async {
  final codec = await ui.instantiateImageCodec(encoded);
  final image = (await codec.getNextFrame()).image;
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    return DecodedImage(image.width, image.height, data!.buffer.asUint8List());
  } finally {
    image.dispose();
    codec.dispose();
  }
}

/// Prepara el pozo como en el entrenamiento (udder_crop de ml/src/udder_public_data.py): recorta
/// [box], lo centra en un cuadrado del lado mayor con relleno negro y lo lleva a [size] × [size] con
/// el filtro bilineal de Pillow. Devuelve RGB de 8 bits.
Uint8List milkInput(DecodedImage image, CropBox box, int size) {
  final b = box.clampTo(image.width, image.height);
  final side = math.max(b.width, b.height);
  final square = Uint8List(side * side * 3);
  final ox = (side - b.width) ~/ 2;
  final oy = (side - b.height) ~/ 2;
  for (var y = 0; y < b.height; y++) {
    for (var x = 0; x < b.width; x++) {
      final from = ((b.top + y) * image.width + b.left + x) * 4;
      final to = ((oy + y) * side + ox + x) * 3;
      square[to] = image.rgba[from];
      square[to + 1] = image.rgba[from + 1];
      square[to + 2] = image.rgba[from + 2];
    }
  }
  return resizeBilinear(square, side, side, size, size);
}

// ------------------------------------------------------------ bilineal de Pillow (Resample.c)
//
// Pillow reduce con antialias: el soporte del filtro triangular crece con la escala, los pesos se
// pasan a enteros de 22 bits y se hace primero la pasada horizontal y después la vertical, cada
// una redondeada a 8 bits. Se copia igual para obtener los mismos píxeles que Python.

const _precisionBits = 32 - 8 - 2;

class _Coefficients {
  _Coefficients(this.bounds, this.weights, this.kernelSize);

  /// Por cada salida: primer índice de entrada y cuántos se usan.
  final List<int> bounds;
  final List<int> weights;
  final int kernelSize;
}

_Coefficients _coefficients(int inSize, int outSize) {
  final scale = inSize / outSize;
  final filterScale = math.max(scale, 1.0);
  final support = 1.0 * filterScale;
  final kernelSize = support.ceil() * 2 + 1;
  final bounds = List<int>.filled(outSize * 2, 0);
  final weights = List<int>.filled(outSize * kernelSize, 0);
  final ss = 1.0 / filterScale;
  for (var xx = 0; xx < outSize; xx++) {
    final center = (xx + 0.5) * scale;
    var xmin = (center - support + 0.5).toInt();
    if (xmin < 0) xmin = 0;
    var xmax = (center + support + 0.5).toInt();
    if (xmax > inSize) xmax = inSize;
    xmax -= xmin;
    final k = List<double>.filled(xmax, 0);
    var total = 0.0;
    for (var x = 0; x < xmax; x++) {
      final distance = ((x + xmin - center + 0.5) * ss).abs();
      final w = distance < 1.0 ? 1.0 - distance : 0.0;
      k[x] = w;
      total += w;
    }
    for (var x = 0; x < xmax; x++) {
      final normalized = total == 0.0 ? k[x] : k[x] / total;
      weights[xx * kernelSize + x] = (0.5 + normalized * (1 << _precisionBits)).toInt();
    }
    bounds[xx * 2] = xmin;
    bounds[xx * 2 + 1] = xmax;
  }
  return _Coefficients(bounds, weights, kernelSize);
}

int _clip8(int value) {
  if (value >= (1 << _precisionBits << 8)) return 255;
  if (value <= 0) return 0;
  return value >> _precisionBits;
}

/// Redimensiona RGB de 8 bits igual que Image.resize(..., Image.Resampling.BILINEAR) de Pillow.
Uint8List resizeBilinear(Uint8List rgb, int inWidth, int inHeight, int outWidth, int outHeight) {
  final horizontal = _coefficients(inWidth, outWidth);
  final vertical = _coefficients(inHeight, outHeight);
  const half = 1 << (_precisionBits - 1);

  // Filas de entrada que usa la pasada vertical
  final first = vertical.bounds[0];
  final last = vertical.bounds[outHeight * 2 - 2] + vertical.bounds[outHeight * 2 - 1];
  final rows = last - first;

  final temp = Uint8List(outWidth * rows * 3);
  for (var y = 0; y < rows; y++) {
    for (var xx = 0; xx < outWidth; xx++) {
      final xmin = horizontal.bounds[xx * 2];
      final count = horizontal.bounds[xx * 2 + 1];
      var r = half, g = half, b = half;
      for (var x = 0; x < count; x++) {
        final w = horizontal.weights[xx * horizontal.kernelSize + x];
        final i = ((y + first) * inWidth + xmin + x) * 3;
        r += rgb[i] * w;
        g += rgb[i + 1] * w;
        b += rgb[i + 2] * w;
      }
      final o = (y * outWidth + xx) * 3;
      temp[o] = _clip8(r);
      temp[o + 1] = _clip8(g);
      temp[o + 2] = _clip8(b);
    }
  }

  final out = Uint8List(outWidth * outHeight * 3);
  for (var yy = 0; yy < outHeight; yy++) {
    final ymin = vertical.bounds[yy * 2] - first;
    final count = vertical.bounds[yy * 2 + 1];
    for (var xx = 0; xx < outWidth; xx++) {
      var r = half, g = half, b = half;
      for (var y = 0; y < count; y++) {
        final w = vertical.weights[yy * vertical.kernelSize + y];
        final i = ((ymin + y) * outWidth + xx) * 3;
        r += temp[i] * w;
        g += temp[i + 1] * w;
        b += temp[i + 2] * w;
      }
      final o = (yy * outWidth + xx) * 3;
      out[o] = _clip8(r);
      out[o + 1] = _clip8(g);
      out[o + 2] = _clip8(b);
    }
  }
  return out;
}
