import 'package:agrovet/data/local/app_database.dart';
import 'package:agrovet/data/local/local_repository.dart';
import 'package:agrovet/domain/entities.dart';
import 'package:agrovet/domain/record_estimates.dart';
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

  /// Contesta las cuatro preguntas del asistente.
  Future<DailyRecordCubit> answerAll(
    FeedAnswer feed,
    MilkAnswer milk,
    BodyAnswer body,
    UdderAnswer udder, {
    bool milking = true,
  }) async {
    final cubit = DailyRecordCubit(repo, cowId: 'c1', date: today, milking: milking);
    await cubit.load();
    cubit.answerFeed(feed);
    if (milking) cubit.answerMilk(milk);
    cubit.answerBody(body);
    cubit.answerUdder(udder);
    return cubit;
  }

  test('al tocar una opción pasa sola a la siguiente; atrás y empezar de nuevo', () async {
    final cubit = DailyRecordCubit(repo, cowId: 'c1', date: today);
    await cubit.load();
    expect(cubit.state.step, RecordStep.feed);
    expect(cubit.state.progress, 0);
    cubit.answerFeed(FeedAnswer.less);
    expect(cubit.state.step, RecordStep.milk);
    expect(cubit.state.questionNumber, 2);
    cubit.back();
    expect(cubit.state.step, RecordStep.feed);
    expect(cubit.state.answers.feed, FeedAnswer.less, reason: 'la respuesta se conserva');
    cubit.answerFeed(FeedAnswer.normal);
    cubit.answerMilk(MilkAnswer.same);
    cubit.answerBody(BodyAnswer.normal);
    cubit.answerUdder(UdderAnswer.normal);
    expect(cubit.state.step, RecordStep.done);
    expect(cubit.state.progress, 1);
    cubit.restart();
    expect(cubit.state.step, RecordStep.feed);
    expect(cubit.state.answers.feed, isNull);
    await cubit.close();
  });

  test('sin historial usa valores de referencia y guarda los valores como estimados', () async {
    final cubit = await answerAll(FeedAnswer.almostNothing, MilkAnswer.muchLess, BodyAnswer.hot, UdderAnswer.abnormalMilk);
    expect(cubit.state.baselines!.usesFallback, isTrue);
    expect(cubit.state.baselines!.milk.kind, BaselineKind.reference);
    await cubit.save();

    final row = await db.select(db.dailyRecords).getSingle();
    expect(row.temperatureC, 40.1); // 38,6 + 1,5
    expect(row.milkL, 9.1); // 13 × 0,7
    expect(row.feedKg, 5.5); // 11 × 0,5
    expect([row.temperatureSource, row.milkSource, row.feedSource], everyElement('estimated'));
    expect(row.ateNormally, isFalse);
    expect(row.milkDrop, isTrue);
    expect(row.abnormalMilk, isTrue);
    expect(row.udderSwelling, isFalse);
    await cubit.close();
  });

  test('la línea base es el promedio de las mediciones exactas anteriores y "No sé" la deja igual', () async {
    await fillDays(5, skipToday: true); // 38,5 °C, 12 L, 10 kg
    // Un valor estimado anterior no cuenta para la línea base
    await repo.saveRecord(DailyRecord(
      id: 'est',
      cowId: 'c1',
      recordDate: dateOnly(today).subtract(const Duration(days: 8)),
      milkL: 2,
      milkSource: ValueSource.estimated,
      updatedAt: today,
    ));
    final cubit = await answerAll(FeedAnswer.unknown, MilkAnswer.unknown, BodyAnswer.unknown, UdderAnswer.unknown);
    expect(cubit.state.baselines!.milk.kind, BaselineKind.average);
    expect(cubit.state.baselines!.milk.samples, 5);
    await cubit.save();

    final row = await (db.select(db.dailyRecords)..where((r) => r.id.isNotIn(['r1', 'r2', 'r3', 'r4', 'r5', 'est'])))
        .getSingle();
    expect([row.temperatureC, row.milkL, row.feedKg], [38.5, 12, 10]);
    // "No sé" no responde las preguntas Sí/No ni marca signos
    expect(row.ateNormally, isNull);
    expect(row.milkDrop, isNull);
    expect(row.udderSwelling || row.abnormalMilk, isFalse);
    await cubit.close();
  });

  test('con una sola medición anterior usa esa medición', () async {
    await fillDays(1, skipToday: true);
    final cubit = await answerAll(FeedAnswer.less, MilkAnswer.littleLess, BodyAnswer.warm, UdderAnswer.inflamed);
    expect(cubit.state.baselines!.temperature.kind, BaselineKind.lastMeasurement);
    final estimate = cubit.state.estimate;
    expect(estimate.temperature!.value, 39.0); // 38,5 + 0,5
    expect(estimate.milk!.value, 10.8); // 12 × 0,9
    expect(estimate.feed!.value, 8.5); // 10 × 0,85
    expect(cubit.state.answers.toSymptoms().udderSwelling, isTrue);
    await cubit.close();
  });

  test('las medidas exactas reemplazan a las estimadas y quedan como medidas', () async {
    final cubit = await answerAll(FeedAnswer.normal, MilkAnswer.same, BodyAnswer.hot, UdderAnswer.normal);
    cubit.setMeasurements(temperatureC: 38.9, milkL: 14.2);
    await cubit.save();

    final row = await db.select(db.dailyRecords).getSingle();
    expect(row.temperatureC, 38.9);
    expect(row.temperatureSource, 'measured');
    expect(row.milkL, 14.2);
    expect(row.milkSource, 'measured');
    expect(row.feedKg, 11.0);
    expect(row.feedSource, 'estimated');
    await cubit.close();
  });

  test('una vaca seca no tiene pregunta de leche ni valor de leche', () async {
    final cubit = await answerAll(FeedAnswer.normal, MilkAnswer.same, BodyAnswer.normal, UdderAnswer.normal,
        milking: false);
    expect(cubit.state.steps, isNot(contains(RecordStep.milk)));
    expect(cubit.state.step, RecordStep.done);
    await cubit.save();
    final row = await db.select(db.dailyRecords).getSingle();
    expect(row.milkL, isNull);
    expect(row.milkSource, isNull);
    await cubit.close();
  });

  test('el registro del mismo día se reemplaza en lugar de duplicarse', () async {
    final first = await answerAll(FeedAnswer.normal, MilkAnswer.same, BodyAnswer.normal, UdderAnswer.abnormalMilk);
    await first.save();

    final again = await answerAll(FeedAnswer.normal, MilkAnswer.same, BodyAnswer.normal, UdderAnswer.normal);
    expect(again.state.existing, isNotNull);
    await again.save();

    final rows = await db.select(db.dailyRecords).get();
    expect(rows, hasLength(1));
    expect(rows.single.abnormalMilk, isFalse);
    await first.close();
    await again.close();
  });

  test('las respuestas nuevas suman en el puntaje por síntomas', () async {
    final cubit = await answerAll(FeedAnswer.less, MilkAnswer.littleLess, BodyAnswer.hot, UdderAnswer.inflamed);
    await cubit.save();
    final record = (await repo.recordsBetween('c1', dateOnly(today), dateOnly(today))).single;
    final assessment = SymptomScore.assess(record);
    // Ubre hinchada 2 + fiebre estimada (40,1 °C) 2 + menos leche 1 + no comió normal 1
    expect(assessment.score, 6);
    expect(assessment.level, RiskLevel.red);
    await cubit.close();
  });
}