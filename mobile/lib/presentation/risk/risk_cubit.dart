import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities.dart';
import '../../domain/repositories.dart';
import '../../domain/risk_evaluator.dart';

class RiskState extends Equatable {
  const RiskState({this.evaluating = true, this.outcome, this.todaySymptoms = const Symptoms(), this.error});

  final bool evaluating;
  final RiskOutcome? outcome;
  final Symptoms todaySymptoms;
  final String? error;

  @override
  List<Object?> get props => [evaluating, outcome, todaySymptoms, error];
}

/// Evalúa el riesgo con los registros de los últimos 14 días y guarda el resultado
/// (y una alerta si sale amarillo o rojo) para el historial y la sincronización.
class RiskCubit extends Cubit<RiskState> {
  RiskCubit({
    required this.cowId,
    required this._records,
    required this._inferences,
    required this._evaluator,
    DateTime Function()? clock,
    Uuid? uuid,
  })  : _now = clock ?? DateTime.now,
        _uuid = uuid ?? const Uuid(),
        super(const RiskState());

  final String cowId;
  final RecordRepository _records;
  final InferenceRepository _inferences;
  final RiskEvaluator _evaluator;
  final DateTime Function() _now;
  final Uuid _uuid;

  Future<void> evaluate() async {
    emit(const RiskState());
    try {
      final today = dateOnly(_now());
      final from = today.subtract(Duration(days: _evaluator.windowDays - 1));
      final records = await _records.recordsBetween(cowId, from, today);
      final todayRecord = records.where((r) => r.recordDate == today).firstOrNull;
      final outcome = _evaluator.evaluate(records, today);

      if (outcome is RiskResult) {
        final inference = Inference(
          id: _uuid.v4(),
          cowId: cowId,
          windowEndDate: outcome.windowEnd,
          probability: outcome.probability,
          riskLevel: outcome.level,
          modelVersion: _evaluator.predictor.config.modelVersion,
          updatedAt: _now(),
        );
        final alert = outcome.level == RiskLevel.green
            ? null
            : CowAlert(
                id: _uuid.v4(),
                cowId: cowId,
                inferenceId: inference.id,
                riskLevel: outcome.level,
                createdAt: _now(),
              );
        await _inferences.saveInference(inference, alert: alert);
      }
      emit(RiskState(
        evaluating: false,
        outcome: outcome,
        todaySymptoms: todayRecord?.symptoms ?? const Symptoms(),
      ));
    } catch (e) {
      emit(RiskState(evaluating: false, error: 'No se pudo evaluar: $e'));
    }
  }
}
