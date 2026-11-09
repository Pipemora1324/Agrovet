import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_litert/flutter_litert.dart';

import '../../domain/udder_triage.dart';

/// CNN de triaje visual de la ubre (MobileNetV2) exportada a TFLite.
/// Entrada [1, 224, 224, 3] con RGB 0–255 en float (el modelo reescala por dentro); salida [1, 1].
class UdderModel {
  UdderModel._(this._interpreter, this.config);

  static const configAsset = 'assets/model/udder_cnn_config.json';

  final Interpreter _interpreter;
  final UdderModelConfig config;

  static Future<UdderModel> load({AssetBundle? bundle}) async {
    final assets = bundle ?? rootBundle;
    final config = UdderModelConfig.fromJson(
      jsonDecode(await assets.loadString(configAsset)) as Map<String, dynamic>,
    );
    final bytes = await assets.load('assets/model/${config.modelFile}');
    return fromBytes(bytes.buffer.asUint8List(), config);
  }

  static UdderModel fromBytes(Uint8List modelBytes, UdderModelConfig config) =>
      UdderModel._(Interpreter.fromBuffer(modelBytes), config);

  /// [rgb]: inputSize × inputSize × 3 valores en orden fila, columna, canal.
  UdderTriageResult predict(Float32List rgb) {
    final size = config.inputSize;
    if (rgb.length != size * size * 3) {
      throw ArgumentError('Se esperaban ${size * size * 3} valores y llegaron ${rgb.length}');
    }
    final input = rgb.reshape<double>([1, size, size, 3]);
    final output = [
      [0.0],
    ];
    _interpreter.run(input, output);
    return UdderTriageResult(output[0][0], config.threshold);
  }

  void close() => _interpreter.close();
}

/// Prepara una foto como en el entrenamiento: la centra en un cuadrado con relleno negro (sin
/// deformarla) y la lleva a [size] × [size]. En la app no hay polígono de la ubre: la persona debe
/// encuadrar la ubre en la foto.
Future<Float32List> udderInputFromEncoded(Uint8List encoded, int size) async {
  final codec = await ui.instantiateImageCodec(encoded);
  final image = (await codec.getNextFrame()).image;
  final side = image.width > image.height ? image.width : image.height;
  final scale = size / side;
  final width = image.width * scale;
  final height = image.height * scale;
  final recorder = ui.PictureRecorder();
  // El lienzo empieza transparente: al leerlo en RGBA, lo que no cubre la foto queda en (0, 0, 0)
  ui.Canvas(recorder).drawImageRect(
    image,
    ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    ui.Rect.fromLTWH((size - width) / 2, (size - height) / 2, width, height),
    ui.Paint()..filterQuality = ui.FilterQuality.medium,
  );
  final square = await recorder.endRecording().toImage(size, size);
  final rgba = (await square.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  image.dispose();
  square.dispose();
  return rgbaToRgb(rgba);
}

/// RGBA de 8 bits a RGB en float, descartando el canal alfa.
Float32List rgbaToRgb(Uint8List rgba) {
  final pixels = rgba.length ~/ 4;
  final rgb = Float32List(pixels * 3);
  for (var i = 0; i < pixels; i++) {
    rgb[i * 3] = rgba[i * 4].toDouble();
    rgb[i * 3 + 1] = rgba[i * 4 + 1].toDouble();
    rgb[i * 3 + 2] = rgba[i * 4 + 2].toDouble();
  }
  return rgb;
}
