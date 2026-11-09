import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Columnas comunes para sincronizar: fecha de modificación, borrado lógico y si falta subir.
mixin SyncColumns on Table {
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  BoolColumn get syncPending => boolean().withDefault(const Constant(true))();

  /// Datos de demostración (solo en modo debug); nunca se sincronizan.
  BoolColumn get isDemo => boolean().withDefault(const Constant(false))();

  /// Motivo por el que el servidor rechazó el elemento (no se reintenta hasta que cambie).
  TextColumn get syncError => text().nullable()();
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

  /// Origen de cada valor: 'measured' o 'estimated' (null en registros anteriores, escritos a mano).
  TextColumn get temperatureSource => text().nullable()();
  TextColumn get milkSource => text().nullable()();
  TextColumn get feedSource => text().nullable()();
  BoolColumn get udderSwelling => boolean().withDefault(const Constant(false))();
  BoolColumn get abnormalMilk => boolean().withDefault(const Constant(false))();
  BoolColumn get udderPain => boolean().withDefault(const Constant(false))();

  /// Casilla de versiones anteriores ("decaída, come poco"); ya no se pregunta pero se conserva.
  BoolColumn get lethargy => boolean().withDefault(const Constant(false))();
  BoolColumn get udderRedness => boolean().withDefault(const Constant(false))();
  BoolColumn get udderHeat => boolean().withDefault(const Constant(false))();

  /// ¿Comió normal? null = sin respuesta.
  BoolColumn get ateNormally => boolean().nullable()();

  /// ¿Produjo menos leche de lo usual? null = sin respuesta.
  BoolColumn get milkDrop => boolean().nullable()();
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

  /// Probabilidad del modelo; null si no hubo días suficientes con datos numéricos.
  RealColumn get probability => real().nullable()();

  /// Puntaje por síntomas del día (reglas provisionales).
  IntColumn get symptomScore => integer().nullable()();

  /// Qué fijó el color final: MODEL, SYMPTOMS o BOTH.
  TextColumn get cause => text().nullable()();
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

/// Foto de una vaca. El archivo vive en el almacenamiento privado (PhotoStore); aquí, sus datos.
@DataClassName('CowPhotoRow')
class CowPhotos extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get cowId => text().references(Cows, #id)();

  /// Día de la foto como texto AAAA-MM-DD.
  TextColumn get takenOn => text()();
  TextColumn get fileName => text()();
  IntColumn get sizeBytes => integer()();

  /// El archivo ya se subió al servidor (los datos viajan aparte, con la sincronización).
  BoolColumn get imageUploaded => boolean().withDefault(const Constant(false))();

  /// ¿Lo confirmó un veterinario? YES, NO o PENDING (null: sin responder).
  TextColumn get vetConfirmed => text().nullable()();

  /// MASTITIS, HEALTHY u OTHER.
  TextColumn get diagnosis => text().nullable()();
  TextColumn get diagnosisNotes => text().nullable()();

  /// Permiso expreso para usar la foto en investigación; apagado por defecto.
  BoolColumn get researchConsent => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Conversación con el asistente, por vaca. Solo vive en este celular (cifrada); no se sincroniza.
@DataClassName('AssistantMessageRow')
class AssistantMessages extends Table {
  TextColumn get id => text()();
  TextColumn get cowId => text().references(Cows, #id)();
  BoolColumn get fromUser => boolean()();
  TextColumn get body => text()();

  /// La pregunta llevaba una foto (la foto no se guarda aquí).
  BoolColumn get withPhoto => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Cows, DailyRecords, Inferences, Alerts, CowPhotos, AssistantMessages])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(cows, cows.syncError);
            await m.addColumn(dailyRecords, dailyRecords.syncError);
            await m.addColumn(inferences, inferences.syncError);
            await m.addColumn(alerts, alerts.syncError);
          }
          if (from < 3) {
            await m.addColumn(dailyRecords, dailyRecords.udderRedness);
            await m.addColumn(dailyRecords, dailyRecords.udderHeat);
            await m.addColumn(dailyRecords, dailyRecords.ateNormally);
            await m.addColumn(dailyRecords, dailyRecords.milkDrop);
          }
          if (from < 4) {
            // SQLite no permite quitar NOT NULL: se reconstruye la tabla copiando las filas
            await m.alterTable(TableMigration(
              inferences,
              newColumns: [inferences.symptomScore, inferences.cause],
            ));
          }
          if (from < 5) {
            await m.createTable(cowPhotos);
          }
          if (from >= 5 && from < 6) {
            // Si la tabla se creó en este mismo arranque (desde < 5) ya tiene las columnas
            await m.addColumn(cowPhotos, cowPhotos.vetConfirmed);
            await m.addColumn(cowPhotos, cowPhotos.diagnosis);
            await m.addColumn(cowPhotos, cowPhotos.diagnosisNotes);
            await m.addColumn(cowPhotos, cowPhotos.researchConsent);
          }
          if (from < 7) {
            await m.createTable(assistantMessages);
          }
          if (from < 8) {
            await m.addColumn(dailyRecords, dailyRecords.temperatureSource);
            await m.addColumn(dailyRecords, dailyRecords.milkSource);
            await m.addColumn(dailyRecords, dailyRecords.feedSource);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
