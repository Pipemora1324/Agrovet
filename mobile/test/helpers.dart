import 'dart:convert';
import 'dart:io';

import 'package:agrovet/data/local/app_database.dart';
import 'package:agrovet/domain/model_config.dart';
import 'package:agrovet/domain/risk_predictor.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

ModelConfig loadModelConfig() => ModelConfig.fromJson(
      jsonDecode(File('assets/model/model_config.json').readAsStringSync()) as Map<String, dynamic>,
    );

AppDatabase memoryDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

/// Modelo falso: devuelve siempre la misma probabilidad y guarda la última ventana recibida.
class FakePredictor implements RiskPredictor {
  FakePredictor(this.probability, [ModelConfig? config]) : config = config ?? loadModelConfig();

  final double probability;
  List<List<double>>? lastWindow;

  @override
  final ModelConfig config;

  @override
  double predict(List<List<double>> normalizedWindow) {
    lastWindow = normalizedWindow;
    return probability;
  }
}
