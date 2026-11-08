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

/// Lo que el ganadero observa en el día: dos preguntas Sí/No (pueden quedar sin responder) y los
/// signos de la ubre.
class Symptoms extends Equatable {
  const Symptoms({
    this.udderSwelling = false,
    this.abnormalMilk = false,
    this.udderPain = false,
    this.lethargy = false,
    this.udderRedness = false,
    this.udderHeat = false,
    this.ateNormally,
    this.milkDrop,
  });

  /// Ubre hinchada.
  final bool udderSwelling;

  /// Grumos o sangre en la leche.
  final bool abnormalMilk;

  /// Dolor al tocar.
  final bool udderPain;

  /// Casilla de versiones anteriores ("decaída, come poco"). Ya no se pregunta; se conserva.
  final bool lethargy;

  /// Ubre enrojecida.
  final bool udderRedness;

  /// Ubre caliente.
  final bool udderHeat;

  /// ¿Comió normal? null = sin respuesta.
  final bool? ateNormally;

  /// ¿Produjo menos leche de lo usual? null = sin respuesta.
  final bool? milkDrop;

  /// Algún signo en la ubre o en la leche.
  bool get anyUdderSign => udderRedness || udderSwelling || udderHeat || udderPain || abnormalMilk;

  /// Algo fuera de lo normal: un signo de la ubre, no comió normal, dio menos leche o estaba decaída.
  bool get any => anyUdderSign || lethargy || ateNormally == false || milkDrop == true;

  /// Respondió alguna pregunta o marcó algún signo.
  bool get anyAnswer => anyUdderSign || lethargy || ateNormally != null || milkDrop != null;

  Symptoms copyWith({
    bool? udderSwelling,
    bool? abnormalMilk,
    bool? udderPain,
    bool? lethargy,
    bool? udderRedness,
    bool? udderHeat,
    bool? Function()? ateNormally,
    bool? Function()? milkDrop,
  }) =>
      Symptoms(
        udderSwelling: udderSwelling ?? this.udderSwelling,
        abnormalMilk: abnormalMilk ?? this.abnormalMilk,
        udderPain: udderPain ?? this.udderPain,
        lethargy: lethargy ?? this.lethargy,
        udderRedness: udderRedness ?? this.udderRedness,
        udderHeat: udderHeat ?? this.udderHeat,
        // Función para poder volver a "sin respuesta" (null)
        ateNormally: ateNormally == null ? this.ateNormally : ateNormally(),
        milkDrop: milkDrop == null ? this.milkDrop : milkDrop(),
      );

  @override
  List<Object?> get props =>
      [udderSwelling, abnormalMilk, udderPain, lethargy, udderRedness, udderHeat, ateNormally, milkDrop];
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
