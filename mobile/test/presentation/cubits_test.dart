import 'package:agrovet/data/local/app_database.dart';
import 'package:agrovet/data/local/local_repository.dart';
import 'package:agrovet/domain/entities.dart';
import 'package:agrovet/domain/risk_evaluator.dart';
import 'package:agrovet/domain/symptom_score.dart';
import 'package:agrovet/presentation/records/daily_record_cubit.dart';
import 'package:agrovet/presentation/risk/risk_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;
  late LocalRepository repo;
  final today = DateTime(2026, 3, 20, 9, 30);

  setUp(() async {
    db = memoryDatabase();
    repo = LocalRepository(db);
    await repo.saveCow(Cow(id: 'c1', tag: 'V-01', productionStatus: ProductionStatus.lactating, updatedAt: today));
  });

  tearDown(() => db.close());

  /// [count] días con mediciones terminando hoy (o ayer si [skipToday]); el de hoy con [todaySymptoms].
  Future<void> fillDays(int count, {Symptoms todaySymptoms = const Symptoms(), bool skipToday = false}) async {
    for (var i = skipToday ? 1 : 0; i < count + (skipToday ? 1 : 0); i++) {
      await repo.saveRecord(DailyRecord(
        id: 'r$i',
        cowId: 'c1',
        recordDate: dateOnly(today).subtract(Duration(days: i)),
        temperatureC: 38.5,
        milkL: 12,
        feedKg: 10,
        symptoms: i == 0 ? todaySymptoms : const Symptoms(),
        updatedAt: today,
      ));
    }
  }

  RiskCubit riskCubit(double probability) => RiskCubit(
        cowId: 'c1',
        records: repo,
        inferences: repo,
        evaluator: RiskEvaluator(FakePredictor(probability)),
        clock: () => today,
      );

  test('el modelo en rojo y los síntomas en amarillo dan rojo, causado por el modelo', () async {
    await fillDays(14, todaySymptoms: const Symptoms(udderSwelling: true));
    final cubit = riskCubit(0.95);
    await cubit.evaluate();
    final outcome = cubit.state.outcome as CombinedRisk;
    expect(outcome.level, RiskLevel.red);
    expect(outcome.cause, RiskCause.model);
    expect(cubit.state.todaySymptoms.udderSwelling, isTrue);

    final inference = await db.select(db.inferences).getSingle();
    expect(inference.probability, 0.95);
    expect(inference.symptomScore, 2);
    expect(inference.cause, 'MODEL');
    final alert = await db.select(db.alerts).getSingle();
    expect(alert.riskLevel, 'RED');
    await cubit.close();
  });

  test('los síntomas pueden subir el color aunque el modelo esté en verde', () async {
    await fillDays(14, todaySymptoms: const Symptoms(abnormalMilk: true, udderHeat: true));
    final cubit = riskCubit(0.05);
    await cubit.evaluate();
    final outcome = cubit.state.outcome as CombinedRisk;
    expect(outcome.level, RiskLevel.red);
    expect(outcome.cause, RiskCause.symptoms);
    expect((await db.select(db.alerts).getSingle()).riskLevel, 'RED');
    await cubit.close();
  });

  test('todo verde guarda la evaluación sin alerta', () async {
    await fillDays(14);
    final cubit = riskCubit(0.05);
    await cubit.evaluate();
    expect((cubit.state.outcome as CombinedRisk).cause, RiskCause.both);
    expect(await db.select(db.inferences).get(), hasLength(1));
    expect(await db.select(db.alerts).get(), isEmpty);
    await cubit.close();
  });

  test('con pocos días evalúa solo con los síntomas y no usa el modelo', () async {
    await fillDays(5, todaySymptoms: const Symptoms(abnormalMilk: true));
    final predictor = FakePredictor(0.95);
    final cubit = RiskCubit(
      cowId: 'c1',
      records: repo,
      inferences: repo,
      evaluator: RiskEvaluator(predictor),
      clock: () => today,
    );
    await cubit.evaluate();
    final outcome = cubit.state.outcome as CombinedRisk;
    expect(outcome.model, isNull);
    expect(outcome.modelMissing!.recordedDays, 5);
    expect(outcome.level, RiskLevel.yellow);
    expect(outcome.cause, RiskCause.symptoms);
    expect(predictor.lastWindow, isNull);

    final inference = await db.select(db.inferences).getSingle();
    expect(inference.probability, isNull);
    expect(inference.symptomScore, 3);
    expect(inference.modelVersion, SymptomScore.version);
    await cubit.close();
  });

  test('sin registro de hoy y con pocos días no hay nada que evaluar ni guardar', () async {
    await fillDays(5, skipToday: true);
    final cubit = riskCubit(0.95);
    await cubit.evaluate();
    expect(cubit.state.outcome, isA<NothingToEvaluate>());
    expect(await db.select(db.inferences).get(), isEmpty);
    await cubit.close();
  });

  test('el registro del mismo día se edita en lugar de duplicarse', () async {
    final cubit = DailyRecordCubit(repo, cowId: 'c1', date: today);
    await cubit.load();
    cubit.updateSymptoms(const Symptoms(abnormalMilk: true));
    await cubit.save(temperatureC: 38.7, milkL: 12);

    final again = DailyRecordCubit(repo, cowId: 'c1', date: today);
    await again.load();
    expect(again.state.existing, isNotNull);
    expect(again.state.symptoms.abnormalMilk, isTrue);
    await again.save(temperatureC: 39.1, milkL: 11);

    final rows = await db.select(db.dailyRecords).get();
    expect(rows, hasLength(1));
    expect(rows.single.temperatureC, 39.1);
    await cubit.close();
    await again.close();
  });

  test('las preguntas simples se guardan y "sin respuesta" se distingue de "no"', () async {
    final cubit = DailyRecordCubit(repo, cowId: 'c1', date: today);
    await cubit.load();
    cubit.updateSymptoms(cubit.state.symptoms.copyWith(ateNormally: () => false, udderHeat: true));
    await cubit.save();

    final again = DailyRecordCubit(repo, cowId: 'c1', date: today);
    await again.load();
    expect(again.state.symptoms.ateNormally, isFalse);
    expect(again.state.symptoms.milkDrop, isNull);
    expect(again.state.symptoms.udderHeat, isTrue);
    expect(again.state.symptoms.any, isTrue);

    // Volver a "sin respuesta"
    again.updateSymptoms(again.state.symptoms.copyWith(ateNormally: () => null));
    await again.save();
    final row = await db.select(db.dailyRecords).getSingle();
    expect(row.ateNormally, isNull);
    await cubit.close();
    await again.close();
  });

  test('temperatura, leche y alimento son opcionales: se guarda solo con síntomas', () async {
    final cubit = DailyRecordCubit(repo, cowId: 'c1', date: today);
    await cubit.load();
    cubit.updateSymptoms(const Symptoms(udderPain: true));
    await cubit.save();

    final row = await db.select(db.dailyRecords).getSingle();
    expect([row.temperatureC, row.milkL, row.feedKg], everyElement(isNull));
    expect(row.udderPain, isTrue);
    expect(row.syncPending, isTrue);
    await cubit.close();
  });
}
