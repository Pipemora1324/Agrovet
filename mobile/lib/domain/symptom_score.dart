import 'package:equatable/equatable.dart';

import 'entities.dart';

/// Una regla del puntaje: qué se observa y cuántos puntos suma.
class SymptomRule {
  const SymptomRule(this.label, this.points, this.applies);

  final String label;
  final int points;
  final bool Function(DailyRecord record) applies;
}

/// Puntaje por síntomas del registro del día.
///
/// **Reglas provisionales, a validar con un veterinario.** Se basan en los signos clásicos de la
/// mastitis clínica (cambios en la leche e inflamación de la ubre) y en señales generales de que la
/// vaca no está bien. No son un diagnóstico. Están documentadas en docs/symptom_score.md; si se
/// cambian, hay que subir [version] y actualizar ese documento.
class SymptomScore {
  SymptomScore._();

  static const version = 'sintomas-provisional-1';

  static const notice = 'Reglas provisionales, a validar con un veterinario.';

  /// Temperatura desde la que se cuenta fiebre (°C).
  static const feverC = 39.5;

  /// Desde estos puntos el resultado es amarillo y rojo.
  static const yellowFrom = 2;
  static const redFrom = 4;

  static final rules = <SymptomRule>[
    SymptomRule('Grumos o sangre en la leche', 3, (r) => r.symptoms.abnormalMilk),
    SymptomRule('Ubre hinchada', 2, (r) => r.symptoms.udderSwelling),
    SymptomRule('Ubre caliente', 2, (r) => r.symptoms.udderHeat),
    SymptomRule('Dolor al tocar la ubre', 2, (r) => r.symptoms.udderPain),
    SymptomRule('Fiebre (39,5 °C o más)', 2, (r) => (r.temperatureC ?? 0) >= feverC),
    SymptomRule('Ubre enrojecida', 1, (r) => r.symptoms.udderRedness),
    SymptomRule('Dio menos leche de lo usual', 1, (r) => r.symptoms.milkDrop == true),
    SymptomRule('No comió normal', 1, (r) => r.symptoms.ateNormally == false || r.symptoms.lethargy),
  ];

  static SymptomAssessment assess(DailyRecord record) {
    final matched = [for (final rule in rules) if (rule.applies(record)) rule];
    final score = matched.fold<int>(0, (sum, rule) => sum + rule.points);
    return SymptomAssessment(
      score: score,
      level: levelFor(score),
      reasons: [for (final rule in matched) (label: rule.label, points: rule.points)],
      recordDate: dateOnly(record.recordDate),
    );
  }

  static RiskLevel levelFor(int score) {
    if (score >= redFrom) return RiskLevel.red;
    if (score >= yellowFrom) return RiskLevel.yellow;
    return RiskLevel.green;
  }
}

class SymptomAssessment extends Equatable {
  const SymptomAssessment({
    required this.score,
    required this.level,
    required this.reasons,
    required this.recordDate,
  });

  final int score;
  final RiskLevel level;

  /// Lo que sumó puntos, en el orden de las reglas.
  final List<({String label, int points})> reasons;
  final DateTime recordDate;

  @override
  List<Object?> get props => [score, level, reasons, recordDate];
}
