import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_litert/flutter_litert.dart';

import '../../domain/model_config.dart';
import '../../domain/risk_predictor.dart';

/// Modelo LSTM exportado a TFLite: entrada [1, 14, 3] ya normalizada, salida [1, 1].
class RiskModel implements RiskPredictor {
  RiskModel._(this._interpreter, this.config);

  static const configAsset = 'assets/model/model_config.json';

  final Interpreter _interpreter;
  @override
  final ModelConfig config;

  static Future<RiskModel> load({AssetBundle? bundle}) async {
    final assets = bundle ?? rootBundle;
    final config = ModelConfig.fromJson(
      jsonDecode(await assets.loadString(configAsset)) as Map<String, dynamic>,
    );
    final bytes = await assets.load('assets/model/${config.modelFile}');
    return fromBytes(bytes.buffer.asUint8List(), config);
  }

  static RiskModel fromBytes(Uint8List modelBytes, ModelConfig config) =>
      RiskModel._(Interpreter.fromBuffer(modelBytes), config);

  @override
  double predict(List<List<double>> normalizedWindow) {
    final input = [normalizedWindow];
    final output = [
      [0.0],
    ];
    _interpreter.run(input, output);
    return output[0][0];
  }

  void close() => _interpreter.close();
}
