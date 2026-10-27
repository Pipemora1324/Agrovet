import 'package:equatable/equatable.dart';

enum ProductionStatus {
  lactating('LACTATING', 'En ordeño'),
  dry('DRY', 'Seca'),
  heifer('HEIFER', 'Novilla');

  const ProductionStatus(this.code, this.label);

  /// Valor que usa la API y la base local.
  final String code;

  /// Texto que ve el ganadero.
  final String label;

  static ProductionStatus fromCode(String code) =>
      values.firstWhere((s) => s.code == code, orElse: () => lactating);
}

enum RiskLevel {
  green('GREEN', 'Sin señales de riesgo'),
  yellow('YELLOW', 'Alerta temprana'),
  red('RED', 'Alto riesgo');

  const RiskLevel(this.code, this.label);

  final String code;
  final String label;

  static RiskLevel fromCode(String code) =>
      values.firstWhere((r) => r.code == code, orElse: () => green);
}

class Cow extends Equatable {
  const Cow({
    required this.id,
    required this.tag,
    this.name,
    this.breed,
    this.birthDate,
    this.calvings,
    required this.productionStatus,
    required this.updatedAt,
    this.isDemo = false,
  });

  final String id;
  final String tag;
  final String? name;
  final String? breed;
  final DateTime? birthDate;
  final int? calvings;
  final ProductionStatus productionStatus;
  final DateTime updatedAt;
  final bool isDemo;

  String get displayName => name == null || name!.isEmpty ? tag : '$name · $tag';

  @override
  List<Object?> get props =>
      [id, tag, name, breed, birthDate, calvings, productionStatus, updatedAt, isDemo];
}

/// Checklist de síntomas visibles del registro diario.
class Symptoms extends Equatable {
  const Symptoms({
    this.udderSwelling = false,
    this.abnormalMilk = false,
    this.udderPain = false,
    this.lethargy = false,
  });

  final bool udderSwelling;
  final bool abnormalMilk;
  final bool udderPain;
  final bool lethargy;

  bool get any => udderSwelling || abnormalMilk || udderPain || lethargy;

  int get count => [udderSwelling, abnormalMilk, udderPain, lethargy].where((s) => s).length;

  Symptoms copyWith({bool? udderSwelling, bool? abnormalMilk, bool? udderPain, bool? lethargy}) =>
      Symptoms(
        udderSwelling: udderSwelling ?? this.udderSwelling,
        abnormalMilk: abnormalMilk ?? this.abnormalMilk,
        udderPain: udderPain ?? this.udderPain,
        lethargy: lethargy ?? this.lethargy,
      );

  @override
  List<Object?> get props => [udderSwelling, abnormalMilk, udderPain, lethargy];
}

class DailyRecord extends Equatable {
  const DailyRecord({
    required this.id,
    required this.cowId,
    required this.recordDate,
    this.temperatureC,
    this.milkL,
    this.feedKg,
    this.symptoms = const Symptoms(),
    this.notes,
    required this.updatedAt,
  });

  final String id;
  final String cowId;

  /// Solo la fecha (sin hora).
  final DateTime recordDate;
  final double? temperatureC;
  final double? milkL;
  final double? feedKg;
  final Symptoms symptoms;
  final String? notes;
  final DateTime updatedAt;

  @override
  List<Object?> get props =>
      [id, cowId, recordDate, temperatureC, milkL, feedKg, symptoms, notes, updatedAt];
}

class Inference extends Equatable {
  const Inference({
    required this.id,
    required this.cowId,
    required this.windowEndDate,
    required this.probability,
    required this.riskLevel,
    required this.modelVersion,
    required this.updatedAt,
  });

  final String id;
  final String cowId;
  final DateTime windowEndDate;
  final double probability;
  final RiskLevel riskLevel;
  final String modelVersion;
  final DateTime updatedAt;

  @override
  List<Object?> get props =>
      [id, cowId, windowEndDate, probability, riskLevel, modelVersion, updatedAt];
}

class CowAlert extends Equatable {
  const CowAlert({
    required this.id,
    required this.cowId,
    this.inferenceId,
    required this.riskLevel,
    this.attended = false,
    this.attendedAt,
    required this.createdAt,
  });

  final String id;
  final String cowId;
  final String? inferenceId;
  final RiskLevel riskLevel;
  final bool attended;
  final DateTime? attendedAt;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, cowId, inferenceId, riskLevel, attended, attendedAt, createdAt];
}

/// Fecha sin hora, en hora local.
DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);
