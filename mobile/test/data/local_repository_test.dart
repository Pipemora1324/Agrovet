import 'package:agrovet/data/local/app_database.dart';
import 'package:agrovet/data/local/local_repository.dart';
import 'package:agrovet/domain/entities.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
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

  group('alertas', () {
    final later = day.add(const Duration(hours: 3));

    Future<void> seedAlerts(LocalRepository repository) async {
      await repository.saveCow(cow('a', 'V-01'));
      for (final (id, level, created) in [
        ('al1', RiskLevel.yellow, day.subtract(const Duration(days: 1))),
        ('al2', RiskLevel.red, day),
      ]) {
        await repository.saveInference(
          Inference(
              id: 'i-$id', cowId: 'a', windowEndDate: created, probability: 0.9, riskLevel: level, modelVersion: 'x', updatedAt: day),
          alert: CowAlert(id: id, cowId: 'a', inferenceId: 'i-$id', riskLevel: level, createdAt: created),
        );
      }
      // Como si ya se hubieran sincronizado
      await db.update(db.alerts).write(const AlertsCompanion(syncPending: Value(false)));
    }

    test('lista las alertas sin atender, la más reciente primero', () async {
      await seedAlerts(repo);
      final pending = await repo.watchPendingAlerts('a').first;
      expect(pending.map((a) => a.id), ['al2', 'al1']);
      expect(pending.first.riskLevel, RiskLevel.red);
      expect(await repo.watchPendingAlerts('otra').first, isEmpty);
    });

    test('marcar como atendida guarda la fecha y la deja pendiente de sincronizar', () async {
      final clocked = LocalRepository(db, clock: () => later);
      await seedAlerts(clocked);

      await clocked.markAlertAttended('al2');

      final row = await (db.select(db.alerts)..where((a) => a.id.equals('al2'))).getSingle();
      expect(row.attended, isTrue);
      expect(row.attendedAt, later);
      expect(row.updatedAt, later);
      expect(row.syncPending, isTrue);
      expect((await clocked.watchPendingAlerts('a').first).map((a) => a.id), ['al1']);
      final untouched = await (db.select(db.alerts)..where((a) => a.id.equals('al1'))).getSingle();
      expect(untouched.syncPending, isFalse);
    });

    test('marcar dos veces no cambia la fecha de atención', () async {
      var now = later;
      final clocked = LocalRepository(db, clock: () => now);
      await seedAlerts(clocked);
      await clocked.markAlertAttended('al1');
      now = later.add(const Duration(days: 1));
      await clocked.markAlertAttended('al1');
      final row = await (db.select(db.alerts)..where((a) => a.id.equals('al1'))).getSingle();
      expect(row.attendedAt, later);
    });
  });

  test('en la sesión de demostración todo queda marcado como demo', () async {
    final demo = LocalRepository(db, isDemo: true);
    await demo.saveCow(cow('d', 'DEMO-01'));
    expect((await db.select(db.cows).getSingle()).isDemo, isTrue);
  });
}
