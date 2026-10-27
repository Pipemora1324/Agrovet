import 'entities.dart';
import 'preprocessor.dart';
import 'risk_predictor.dart';

sealed class RiskOutcome {
  const RiskOutcome();
}

/// No hay suficientes días registrados para evaluar.
class InsufficientData extends RiskOutcome {
  const InsufficientData({required this.recordedDays, required this.requiredDays, required this.windowDays});

  final int recordedDays;
  final int requiredDays;
  final int windowDays;

  String get message =>
      'Hay $recordedDays de los últimos $windowDays días con datos completos. '
      'Se necesitan al menos $requiredDays para evaluar.';
}

class RiskResult extends RiskOutcome {
  const RiskResult({required this.probability, required this.level, required this.windowEnd});

  final double probability;
  final RiskLevel level;
  final DateTime windowEnd;
}

/// Arma la ventana de los últimos días, la preprocesa como en Python y consulta el modelo.
class RiskEvaluator {
  RiskEvaluator(this.predictor) : preprocessor = Preprocessor(predictor.config);

  final RiskPredictor predictor;
  final Preprocessor preprocessor;

  int get windowDays => predictor.config.windowDays;

  /// Ventana cruda: un día sin registro queda con los tres valores vacíos.
  List<List<double?>> rawWindow(List<DailyRecord> records, DateTime windowEnd) {
    final end = dateOnly(windowEnd);
    final byDate = {for (final r in records) dateOnly(r.recordDate): r};
    return [
      for (var offset = windowDays - 1; offset >= 0; offset--)
        () {
          final record = byDate[DateTime(end.year, end.month, end.day - offset)];
          return [record?.temperatureC, record?.milkL, record?.feedKg];
        }(),
    ];
  }

  RiskOutcome evaluate(List<DailyRecord> records, DateTime windowEnd) {
    final raw = rawWindow(records, windowEnd);
    final normalized = preprocessor.preprocess(raw);
    if (normalized == null) {
      return InsufficientData(
        recordedDays: raw.where((day) => day.every((v) => v != null)).length,
        requiredDays: predictor.config.minValidDays,
        windowDays: windowDays,
      );
    }
    final probability = predictor.predict(normalized);
    return RiskResult(
      probability: probability,
      level: predictor.config.riskLevelFor(probability),
      windowEnd: dateOnly(windowEnd),
    );
  }
}
