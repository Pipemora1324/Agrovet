import 'package:equatable/equatable.dart';

import 'entities.dart';

/// Vaca con su último resultado del semáforo, para la lista principal.
class CowSummary extends Equatable {
  const CowSummary({required this.cow, this.lastRisk, this.lastRecordDate});

  final Cow cow;
  final RiskLevel? lastRisk;
  final DateTime? lastRecordDate;

  @override
  List<Object?> get props => [cow, lastRisk, lastRecordDate];
}

abstract interface class CowRepository {
  Stream<List<CowSummary>> watchCows();
  Stream<Cow?> watchCow(String id);
  Future<void> saveCow(Cow cow);
  Future<void> deleteCow(String id);
  Future<bool> isTagInUse(String tag, {String? exceptId});
}

abstract interface class RecordRepository {
  Future<DailyRecord?> recordFor(String cowId, DateTime date);
  Future<void> saveRecord(DailyRecord record);
  Future<List<DailyRecord>> recordsBetween(String cowId, DateTime from, DateTime to);
}

abstract interface class InferenceRepository {
  /// Guarda el resultado y, si es amarillo o rojo, la alerta asociada.
  Future<void> saveInference(Inference inference, {CowAlert? alert});
  Stream<Inference?> watchLatest(String cowId);
  Future<List<Inference>> inferencesBetween(String cowId, DateTime from, DateTime to);
}

abstract interface class AlertRepository {
  /// Alertas que el ganadero todavía no ha atendido, de la más reciente a la más antigua.
  Stream<List<CowAlert>> watchPendingAlerts(String cowId);

  /// Marca la alerta como atendida; queda pendiente de sincronizar.
  Future<void> markAlertAttended(String alertId);
}
