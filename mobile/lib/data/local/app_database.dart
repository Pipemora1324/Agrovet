import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Columnas comunes para sincronizar: fecha de modificación, borrado lógico y si falta subir.
mixin SyncColumns on Table {
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  BoolColumn get syncPending => boolean().withDefault(const Constant(true))();

  /// Datos de demostración (solo en modo debug); nunca se sincronizan.
  BoolColumn get isDemo => boolean().withDefault(const Constant(false))();
}

@DataClassName('CowRow')
class Cows extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get tag => text().withLength(min: 1, max: 40)();
  TextColumn get name => text().nullable()();
  TextColumn get breed => text().nullable()();
  DateTimeColumn get birthDate => dateTime().nullable()();
  IntColumn get calvings => integer().nullable()();
  TextColumn get productionStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DailyRecordRow')
class DailyRecords extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get cowId => text().references(Cows, #id)();

  /// Fecha del registro como texto AAAA-MM-DD.
  TextColumn get recordDate => text()();
  RealColumn get temperatureC => real().nullable()();
  RealColumn get milkL => real().nullable()();
  RealColumn get feedKg => real().nullable()();
  BoolColumn get udderSwelling => boolean().withDefault(const Constant(false))();
  BoolColumn get abnormalMilk => boolean().withDefault(const Constant(false))();
  BoolColumn get udderPain => boolean().withDefault(const Constant(false))();
  BoolColumn get lethargy => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {cowId, recordDate},
      ];
}

@DataClassName('InferenceRow')
class Inferences extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get cowId => text().references(Cows, #id)();
  TextColumn get windowEndDate => text()();
  RealColumn get probability => real()();
  TextColumn get riskLevel => text()();
  TextColumn get modelVersion => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AlertRow')
class Alerts extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get cowId => text().references(Cows, #id)();
  TextColumn get inferenceId => text().nullable().references(Inferences, #id)();
  TextColumn get riskLevel => text()();
  BoolColumn get attended => boolean().withDefault(const Constant(false))();
  DateTimeColumn get attendedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Cows, DailyRecords, Inferences, Alerts])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
