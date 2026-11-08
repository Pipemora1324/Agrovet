import 'entities.dart';
import 'preprocessor.dart';
import 'risk_predictor.dart';
import 'symptom_score.dart';

sealed class RiskOutcome {
  const RiskOutcome();
}

/// No hay suficientes días con datos numéricos para el modelo.
class InsufficientData extends RiskOutcome {
  const InsufficientData({required this.recordedDays, required this.requiredDays, required this.windowDays});

  final int recordedDays;
  final int requiredDays;
  final int windowDays;

  String get message =>
      'Hay $recordedDays de los últimos $windowDays días con temperatura, leche y alimento. '
      'El modelo necesita al menos $requiredDays.';
}

/// Resultado del modelo LSTM.
class RiskResult extends RiskOutcome {
  const RiskResult({required this.probability, required this.level, required this.windowEnd});

  final double probability;
  final RiskLevel level;
  final DateTime windowEnd;
}

/// Sin registro del día y sin datos para el modelo: no hay nada que evaluar.
class NothingToEvaluate extends RiskOutcome {
  const NothingToEvaluate(this.modelMissing);

  final InsufficientData modelMissing;
}

/// Semáforo final: el más grave entre el modelo y el puntaje por síntomas.
class CombinedRisk extends RiskOutcome {
  const CombinedRisk({
    required this.level,
    required this.cause,
    required this.evaluatedOn,
    this.model,
    this.modelMissing,
    this.symptoms,
  });

  final RiskLevel level;
  final RiskCause cause;
  final DateTime evaluatedOn;

  /// Resultado del modelo, o null si faltaron datos ([modelMissing] dice cuántos).
  final RiskResult? model;
  final InsufficientData? modelMissing;

  /// Puntaje por síntomas del día, o null si no hay registro de ese día.
  final SymptomAssessment? symptoms;
}

/// Arma la ventana de los últimos días, la preprocesa como en Python y consulta el modelo; además
/// calcula el puntaje por síntomas del día y combina los dos.
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

  /// Solo el modelo: RiskResult, o InsufficientData si no hay días suficientes.
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

  /// Semáforo final del día: modelo (si hay datos) y síntomas del registro de ese día (si existe).
  RiskOutcome evaluateDay(List<DailyRecord> records, DateTime day) {
    final today = dateOnly(day);
    final model = evaluate(records, today);
    final todayRecord = records.where((r) => dateOnly(r.recordDate) == today).firstOrNull;
    final symptoms = todayRecord == null ? null : SymptomScore.assess(todayRecord);
    return combine(model: model, symptoms: symptoms, day: today);
  }

  static RiskOutcome combine({required RiskOutcome model, SymptomAssessment? symptoms, required DateTime day}) {
    final modelResult = model is RiskResult ? model : null;
    final missing = model is InsufficientData ? model : null;
    if (modelResult == null && symptoms == null) return NothingToEvaluate(missing!);

    final RiskLevel level;
    final RiskCause cause;
    if (modelResult == null) {
      (level, cause) = (symptoms!.level, RiskCause.symptoms);
    } else if (symptoms == null) {
      (level, cause) = (modelResult.level, RiskCause.model);
    } else if (modelResult.level == symptoms.level) {
      (level, cause) = (symptoms.level, RiskCause.both);
    } else if (modelResult.level.index > symptoms.level.index) {
      (level, cause) = (modelResult.level, RiskCause.model);
    } else {
      (level, cause) = (symptoms.level, RiskCause.symptoms);
    }
    return CombinedRisk(
      level: level,
      cause: cause,
      evaluatedOn: dateOnly(day),
      model: modelResult,
      modelMissing: missing,
      symptoms: symptoms,
    );
  }
}
