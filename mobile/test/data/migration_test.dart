import 'dart:io';

import 'package:agrovet/data/local/app_database.dart';
import 'package:agrovet/data/local/database_opener.dart';
import 'package:agrovet/data/local/local_repository.dart';
import 'package:agrovet/data/security/secure_store.dart';
import 'package:drift/drift.dart' hide DatabaseOpener, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Columnas que agregó la versión 3 del esquema (preguntas simples y signos de la ubre).
const _v3Columns = ['udder_redness', 'udder_heat', 'ate_normally', 'milk_drop'];

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('agrovet_migracion_');
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('una base cifrada de la versión 2 sube a la 3 sin perder registros', () async {
    final file = File('${dir.path}/usuario.db');
    final key = SecureStore.generateHexKey();

    // 1. Base actual con un registro
    var db = AppDatabase(DatabaseOpener.openFile(file, key));
    final repo = LocalRepository(db);
    await db.into(db.cows).insert(CowsCompanion.insert(
          id: 'c1',
          tag: 'V-01',
          productionStatus: 'LACTATING',
          updatedAt: DateTime(2026, 11, 1),
        ));
    await db.into(db.dailyRecords).insert(DailyRecordsCompanion.insert(
          id: 'r1',
          cowId: 'c1',
          recordDate: '2026-11-01',
          temperatureC: const Value(38.6),
          udderSwelling: const Value(true),
          updatedAt: DateTime(2026, 11, 1),
        ));
    await db.into(db.inferences).insert(InferencesCompanion.insert(
          id: 'i1',
          cowId: 'c1',
          windowEndDate: '2026-11-01',
          probability: const Value(0.42),
          riskLevel: 'YELLOW',
          modelVersion: '1.0.0',
          updatedAt: DateTime(2026, 11, 1),
        ));
    await db.into(db.alerts).insert(AlertsCompanion.insert(
          id: 'a1',
          cowId: 'c1',
          inferenceId: const Value('i1'),
          riskLevel: 'YELLOW',
          createdAt: DateTime(2026, 11, 1),
          updatedAt: DateTime(2026, 11, 1),
        ));
    await db.close();

    // 2. Se deja como estaba en la versión 2: sin las columnas nuevas y con la probabilidad obligatoria
    final raw = sqlite3.open(file.path);
    DatabaseOpener.applyKey(raw, key);
    for (final column in _v3Columns) {
      raw.execute('ALTER TABLE daily_records DROP COLUMN $column');
    }
    final v4 = raw.select("SELECT sql FROM sqlite_master WHERE name = 'inferences'").first['sql'] as String;
    final v2 = v4
        .replaceAll('"probability" REAL NULL', '"probability" REAL NOT NULL')
        .replaceAll(RegExp(r', "symptom_score" INTEGER NULL'), '')
        .replaceAll(RegExp(r', "cause" TEXT NULL'), '');
    expect(v2, contains('"probability" REAL NOT NULL'));
    raw.execute('PRAGMA foreign_keys = OFF');
    raw.execute('ALTER TABLE inferences RENAME TO inferences_v4');
    raw.execute(v2);
    raw.execute('INSERT INTO inferences SELECT updated_at, deleted, sync_pending, is_demo, sync_error, id, cow_id, '
        'window_end_date, probability, risk_level, model_version FROM inferences_v4');
    raw.execute('DROP TABLE inferences_v4');
    raw.execute('PRAGMA user_version = 2');
    raw.close();

    // 3. La app nueva la abre: corre la migración
    db = AppDatabase(DatabaseOpener.openFile(file, key));
    final columns = (await db.customSelect('PRAGMA table_info(daily_records)').get())
        .map((row) => row.read<String>('name'))
        .toSet();
    expect(columns, containsAll(_v3Columns));

    final record = await LocalRepository(db).recordFor('c1', DateTime(2026, 11, 1));
    expect(record!.temperatureC, 38.6);
    expect(record.symptoms.udderSwelling, isTrue);
    // Lo que no existía queda "sin respuesta", no como "no"
    expect(record.symptoms.ateNormally, isNull);
    expect(record.symptoms.milkDrop, isNull);
    expect(record.symptoms.udderRedness, isFalse);
    expect(repo.isDemo, isFalse);

    // v4: la evaluación anterior sigue ahí, con su alerta, y ahora la probabilidad puede faltar
    final migrated = LocalRepository(db);
    final old = await migrated.inferencesBetween('c1', DateTime(2026, 11, 1), DateTime(2026, 11, 1));
    expect(old.single.probability, 0.42);
    expect(old.single.symptomScore, isNull);
    expect(old.single.cause, isNull);
    expect((await migrated.watchPendingAlerts('c1').first).single.inferenceId, 'i1');
    await db.into(db.inferences).insert(InferencesCompanion.insert(
          id: 'i2',
          cowId: 'c1',
          windowEndDate: '2026-11-02',
          symptomScore: const Value(3),
          cause: const Value('SYMPTOMS'),
          riskLevel: 'YELLOW',
          modelVersion: 'sintomas-provisional-1',
          updatedAt: DateTime(2026, 11, 2),
        ));
    expect(await db.select(db.inferences).get(), hasLength(2));

    // v5: la tabla de fotos existe y está vacía
    expect(await db.select(db.cowPhotos).get(), isEmpty);
    await db.close();
  });
}
