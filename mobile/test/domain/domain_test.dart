import 'package:agrovet/core/validators.dart';
import 'package:agrovet/domain/entities.dart';
import 'package:agrovet/domain/preprocessor.dart';
import 'package:agrovet/domain/risk_advice.dart';
import 'package:agrovet/domain/risk_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

DailyRecord record(DateTime date, {double? t = 38.5, double? m = 12, double? f = 10}) => DailyRecord(
      id: date.toIso8601String(),
      cowId: 'c1',
      recordDate: date,
      temperatureC: t,
      milkL: m,
      feedKg: f,
      updatedAt: date,
    );

void main() {
  final config = loadModelConfig();
  final today = DateTime(2026, 3, 20);

  group('Preprocessor', () {
    final preprocessor = Preprocessor(config);
    List<List<double?>> flat() => List.generate(14, (_) => <double?>[38.5, 12, 10]);

    test('una ventana constante se normaliza a cero', () {
      final result = preprocessor.preprocess(flat())!;
      for (final row in result) {
        expect(row, everyElement(closeTo(0, 1e-12)));
      }
    });

    test('usa las fórmulas de model_config', () {
      final raw = flat()..[13] = [39.5, 9, 8];
      final last = preprocessor.preprocess(raw)!.last;
      expect(last[0], closeTo((39.5 - 38.5) / 0.5, 1e-12));
      expect(last[1], closeTo((9 / 12 - 1) / 0.1, 1e-12));
      expect(last[2], closeTo((8 / 10 - 1) / 0.1, 1e-12));
    });

    test('un dato imposible toma el valor válido anterior', () {
      final raw = flat()
        ..[5] = [38.9, 12, 10]
        ..[6] = [101.3, 12, 10];
      expect(preprocessor.clean(raw)![6][0], 38.9);
    });

    test('rechaza la ventana con menos de 10 días válidos en una variable', () {
      final raw = flat();
      for (var i = 0; i < 5; i++) {
        raw[i] = [38.5, null, 10];
      }
      expect(preprocessor.preprocess(raw), isNull);
    });

    test('rechaza una ventana de tamaño distinto', () {
      expect(() => preprocessor.preprocess(flat()..removeLast()), throwsArgumentError);
    });
  });

  group('RiskEvaluator', () {
    test('arma la ventana de 14 días con días vacíos donde no hay registro', () {
      final evaluator = RiskEvaluator(FakePredictor(0.1));
      final raw = evaluator.rawWindow([record(today), record(today.subtract(const Duration(days: 13)))], today);
      expect(raw, hasLength(14));
      expect(raw.first, [38.5, 12, 10]);
      expect(raw[5], [null, null, null]);
      expect(raw.last, [38.5, 12, 10]);
    });

    test('con pocos días registrados explica cuántos faltan', () {
      final evaluator = RiskEvaluator(FakePredictor(0.1));
      final records = [for (var i = 0; i < 6; i++) record(today.subtract(Duration(days: i)))];
      final outcome = evaluator.evaluate(records, today);
      expect(outcome, isA<InsufficientData>());
      expect((outcome as InsufficientData).message, contains('Hay 6 de los últimos 14 días'));
    });

    test('con datos suficientes consulta el modelo y aplica el semáforo', () {
      final predictor = FakePredictor(0.9);
      final records = [for (var i = 0; i < 14; i++) record(today.subtract(Duration(days: i)))];
      final outcome = RiskEvaluator(predictor).evaluate(records, today) as RiskResult;
      expect(outcome.level, RiskLevel.red);
      expect(predictor.lastWindow, hasLength(14));
    });
  });

  group('Semáforo', () {
    test('rangos a partir del umbral', () {
      final t = config.threshold;
      expect(config.riskLevelFor(0), RiskLevel.green);
      expect(config.riskLevelFor(t * 0.5 - 1e-6), RiskLevel.green);
      expect(config.riskLevelFor(t * 0.5), RiskLevel.yellow);
      expect(config.riskLevelFor(t - 1e-6), RiskLevel.yellow);
      expect(config.riskLevelFor(t), RiskLevel.red);
    });

    test('con síntomas visibles la recomendación pide veterinario aunque esté en verde', () {
      final advice = RiskAdvice.forLevel(RiskLevel.green, symptoms: const Symptoms(udderPain: true));
      expect(advice.steps.first, contains('consulte al veterinario'));
      expect(RiskAdvice.forLevel(RiskLevel.red).title, 'Consulte al veterinario');
    });
  });

  group('Validators', () {
    test('acepta coma decimal y valida rangos', () {
      expect(Validators.parseNumber('38,6'), 38.6);
      expect(Validators.temperatureC('38,6'), isNull);
      expect(Validators.temperatureC('101'), 'La temperatura debe estar entre 35 y 42 °C');
      expect(Validators.milkL('abc'), 'Escriba solo números, por ejemplo 38,6');
      expect(Validators.feedKg(''), isNull);
    });

    test('correo y contraseña', () {
      expect(Validators.email('ana@correo.co'), isNull);
      expect(Validators.email('ana@'), 'El correo no es válido');
      expect(Validators.password('corta'), isNotNull);
      expect(Validators.password('clave-segura'), isNull);
    });
  });
}
