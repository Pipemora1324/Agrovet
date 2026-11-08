import 'package:agrovet/domain/entities.dart';
import 'package:agrovet/domain/risk_evaluator.dart';
import 'package:agrovet/domain/symptom_score.dart';
import 'package:flutter_test/flutter_test.dart';

final _day = DateTime(2026, 11, 8);

DailyRecord _record(Symptoms symptoms, {double? temperature}) => DailyRecord(
      id: 'r',
      cowId: 'c1',
      recordDate: _day,
      temperatureC: temperature,
      symptoms: symptoms,
      updatedAt: _day,
    );

void main() {
  group('reglas del puntaje (provisionales)', () {
    test('cada señal suma lo documentado', () {
      final cases = <(Symptoms, double?, int)>[
        (const Symptoms(abnormalMilk: true), null, 3),
        (const Symptoms(udderSwelling: true), null, 2),
        (const Symptoms(udderHeat: true), null, 2),
        (const Symptoms(udderPain: true), null, 2),
        (const Symptoms(), 39.5, 2),
        (const Symptoms(udderRedness: true), null, 1),
        (const Symptoms(milkDrop: true), null, 1),
        (const Symptoms(ateNormally: false), null, 1),
        (const Symptoms(lethargy: true), null, 1),
      ];
      for (final (symptoms, temperature, points) in cases) {
        expect(SymptomScore.assess(_record(symptoms, temperature: temperature)).score, points,
            reason: '$symptoms, $temperature °C');
      }
    });

    test('respuestas "normales" o sin responder no suman', () {
      final assessment = SymptomScore.assess(_record(const Symptoms(ateNormally: true, milkDrop: false),
          temperature: 39.4));
      expect(assessment.score, 0);
      expect(assessment.level, RiskLevel.green);
      expect(assessment.reasons, isEmpty);
    });

    test('umbrales: 0-1 verde, 2-3 amarillo, 4 o más rojo', () {
      expect(SymptomScore.levelFor(1), RiskLevel.green);
      expect(SymptomScore.levelFor(2), RiskLevel.yellow);
      expect(SymptomScore.levelFor(3), RiskLevel.yellow);
      expect(SymptomScore.levelFor(4), RiskLevel.red);
    });

    test('grumos con ubre caliente ya es rojo y explica por qué', () {
      final assessment = SymptomScore.assess(_record(const Symptoms(abnormalMilk: true, udderHeat: true)));
      expect(assessment.score, 5);
      expect(assessment.level, RiskLevel.red);
      expect(assessment.reasons.map((r) => r.label), ['Grumos o sangre en la leche', 'Ubre caliente']);
    });

    test('las reglas están marcadas como provisionales', () {
      expect(SymptomScore.notice, contains('provisionales'));
      expect(SymptomScore.notice, contains('veterinario'));
    });
  });

  group('semáforo combinado', () {
    final yellowSymptoms = SymptomScore.assess(_record(const Symptoms(udderPain: true)));
    final greenSymptoms = SymptomScore.assess(_record(const Symptoms()));
    RiskResult model(RiskLevel level) => RiskResult(probability: 0.5, level: level, windowEnd: _day);
    const missing = InsufficientData(recordedDays: 2, requiredDays: 10, windowDays: 14);

    CombinedRisk combine(RiskOutcome m, SymptomAssessment? s) =>
        RiskEvaluator.combine(model: m, symptoms: s, day: _day) as CombinedRisk;

    test('gana el más grave y se dice cuál fue', () {
      expect(combine(model(RiskLevel.red), yellowSymptoms).level, RiskLevel.red);
      expect(combine(model(RiskLevel.red), yellowSymptoms).cause, RiskCause.model);
      expect(combine(model(RiskLevel.green), yellowSymptoms).level, RiskLevel.yellow);
      expect(combine(model(RiskLevel.green), yellowSymptoms).cause, RiskCause.symptoms);
      expect(combine(model(RiskLevel.yellow), yellowSymptoms).cause, RiskCause.both);
    });

    test('sin datos para el modelo se apoya en los síntomas', () {
      final result = combine(missing, yellowSymptoms);
      expect(result.level, RiskLevel.yellow);
      expect(result.cause, RiskCause.symptoms);
      expect(result.model, isNull);
      expect(result.modelMissing, missing);
    });

    test('sin registro del día usa solo el modelo', () {
      final result = combine(model(RiskLevel.yellow), null);
      expect(result.cause, RiskCause.model);
      expect(result.symptoms, isNull);
    });

    test('sin modelo y sin registro no hay nada que evaluar', () {
      expect(RiskEvaluator.combine(model: missing, symptoms: null, day: _day), isA<NothingToEvaluate>());
      expect(combine(missing, greenSymptoms).level, RiskLevel.green);
    });
  });
}
