import 'package:agrovet/data/local/app_database.dart';
import 'package:agrovet/data/local/local_repository.dart';
import 'package:agrovet/domain/entities.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;
  late LocalRepository repo;
  final day = DateTime(2026, 3, 20);

  Cow cow(String id, String tag) =>
      Cow(id: id, tag: tag, productionStatus: ProductionStatus.lactating, updatedAt: day);

  setUp(() {
    db = memoryDatabase();
    repo = LocalRepository(db);
  });

  tearDown(() => db.close());

  test('guarda vacas pendientes de sincronizar y las lista por identificador', () async {
    await repo.saveCow(cow('b', 'V-02'));
    await repo.saveCow(cow('a', 'V-01'));
    final cows = await repo.watchCows().first;
    expect(cows.map((c) => c.cow.tag), ['V-01', 'V-02']);
    final rows = await db.select(db.cows).get();
    expect(rows.every((r) => r.syncPending && !r.isDemo), isTrue);
  });

  test('el borrado es lógico y oculta la vaca', () async {
    await repo.saveCow(cow('a', 'V-01'));
    await repo.deleteCow('a');
    expect(await repo.watchCows().first, isEmpty);
    final row = await db.select(db.cows).getSingle();
    expect(row.deleted, isTrue);
    expect(row.syncPending, isTrue);
  });

  test('detecta identificadores repetidos', () async {
    await repo.saveCow(cow('a', 'V-01'));
    expect(await repo.isTagInUse('V-01'), isTrue);
    expect(await repo.isTagInUse('V-01', exceptId: 'a'), isFalse);
  });

  test('registros por rango de fechas y uno por día', () async {
    await repo.saveCow(cow('a', 'V-01'));
    for (var i = 0; i < 5; i++) {
      await repo.saveRecord(DailyRecord(
        id: 'r$i',
        cowId: 'a',
        recordDate: day.subtract(Duration(days: i)),
        milkL: 10.0 + i,
        symptoms: Symptoms(abnormalMilk: i == 0),
        updatedAt: day,
      ));
    }
    final range = await repo.recordsBetween('a', day.subtract(const Duration(days: 2)), day);
    expect(range.map((r) => r.milkL), [12.0, 11.0, 10.0]);
    expect((await repo.recordFor('a', day))!.symptoms.abnormalMilk, isTrue);
  });

  test('la lista muestra el último color del semáforo', () async {
    await repo.saveCow(cow('a', 'V-01'));
    await repo.saveInference(Inference(
      id: 'i1',
      cowId: 'a',
      windowEndDate: day.subtract(const Duration(days: 1)),
      probability: 0.2,
      riskLevel: RiskLevel.green,
      modelVersion: 'x',
      updatedAt: day,
    ));
    await repo.saveInference(
      Inference(
          id: 'i2', cowId: 'a', windowEndDate: day, probability: 0.9, riskLevel: RiskLevel.red, modelVersion: 'x', updatedAt: day),
      alert: CowAlert(id: 'al1', cowId: 'a', inferenceId: 'i2', riskLevel: RiskLevel.red, createdAt: day),
    );
    final summary = (await repo.watchCows().first).single;
    expect(summary.lastRisk, RiskLevel.red);
    expect((await db.select(db.alerts).getSingle()).inferenceId, 'i2');
  });

  test('en la sesión de demostración todo queda marcado como demo', () async {
    final demo = LocalRepository(db, isDemo: true);
    await demo.saveCow(cow('d', 'DEMO-01'));
    expect((await db.select(db.cows).getSingle()).isDemo, isTrue);
  });
}
