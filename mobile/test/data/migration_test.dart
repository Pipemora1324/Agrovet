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
    await db.close();

    // 2. Se deja como estaba en la versión 2: sin las columnas nuevas
    final raw = sqlite3.open(file.path);
    DatabaseOpener.applyKey(raw, key);
    for (final column in _v3Columns) {
      raw.execute('ALTER TABLE daily_records DROP COLUMN $column');
    }
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
    await db.close();
  });
}
