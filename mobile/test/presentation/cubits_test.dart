import 'package:agrovet/data/local/app_database.dart';
import 'package:agrovet/data/local/local_repository.dart';
import 'package:agrovet/domain/entities.dart';
import 'package:agrovet/domain/risk_evaluator.dart';
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

  Future<void> fillDays(int count) async {
    for (var i = 0; i < count; i++) {
      await repo.saveRecord(DailyRecord(
        id: 'r$i',
        cowId: 'c1',
        recordDate: dateOnly(today).subtract(Duration(days: i)),
        temperatureC: 38.5,
        milkL: 12,
        feedKg: 10,
        symptoms: Symptoms(udderSwelling: i == 0),
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

  test('un resultado rojo guarda la inferencia y una alerta', () async {
    await fillDays(14);
    final cubit = riskCubit(0.95);
    await cubit.evaluate();
    expect(cubit.state.outcome, isA<RiskResult>());
    expect(cubit.state.todaySymptoms.udderSwelling, isTrue);
    expect(await db.select(db.inferences).get(), hasLength(1));
    final alert = await db.select(db.alerts).getSingle();
    expect(alert.riskLevel, 'RED');
    await cubit.close();
  });

  test('un resultado verde no crea alerta', () async {
    await fillDays(14);
    final cubit = riskCubit(0.05);
    await cubit.evaluate();
    expect(await db.select(db.inferences).get(), hasLength(1));
    expect(await db.select(db.alerts).get(), isEmpty);
    await cubit.close();
  });

  test('sin datos suficientes no guarda nada', () async {
    await fillDays(5);
    final cubit = riskCubit(0.95);
    await cubit.evaluate();
    expect(cubit.state.outcome, isA<InsufficientData>());
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
}
