import 'package:drift/drift.dart';

import '../../domain/entities.dart';
import '../../domain/repositories.dart';
import 'app_database.dart';

/// Fecha como texto AAAA-MM-DD, igual que en la API.
String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime parseDateKey(String value) {
  final parts = value.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

/// Repositorio local sobre la base cifrada. Todo cambio queda pendiente de sincronizar;
/// en la sesión de demostración se marca isDemo y nunca se envía al servidor.
class LocalRepository implements CowRepository, RecordRepository, InferenceRepository, AlertRepository {
  LocalRepository(this.db, {this.isDemo = false, DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final AppDatabase db;
  final bool isDemo;
  final DateTime Function() _now;

  // ---- Vacas ----

  @override
  Stream<List<CowSummary>> watchCows() {
    final query = db.customSelect(
      'SELECT c.*, '
      '(SELECT i.risk_level FROM inferences i WHERE i.cow_id = c.id AND i.deleted = 0 '
      ' ORDER BY i.window_end_date DESC, i.updated_at DESC LIMIT 1) AS last_risk, '
      '(SELECT MAX(d.record_date) FROM daily_records d WHERE d.cow_id = c.id AND d.deleted = 0) '
      ' AS last_record '
      'FROM cows c WHERE c.deleted = 0 ORDER BY c.tag',
      readsFrom: {db.cows, db.inferences, db.dailyRecords},
    );
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          CowSummary(
            cow: _toCow(db.cows.map(row.data)),
            lastRisk: row.readNullable<String>('last_risk') == null
                ? null
                : RiskLevel.fromCode(row.read<String>('last_risk')),
            lastRecordDate: row.readNullable<String>('last_record') == null
                ? null
                : parseDateKey(row.read<String>('last_record')),
          ),
      ],
    );
  }

  @override
  Stream<Cow?> watchCow(String id) =>
      (db.select(db.cows)..where((c) => c.id.equals(id) & c.deleted.equals(false))).watchSingleOrNull().map(
        (row) => row == null ? null : _toCow(row),
      );

  @override
  Future<void> saveCow(Cow cow) => db
      .into(db.cows)
      .insertOnConflictUpdate(
        CowsCompanion.insert(
          id: cow.id,
          tag: cow.tag,
          name: Value(cow.name),
          breed: Value(cow.breed),
          birthDate: Value(cow.birthDate),
          calvings: Value(cow.calvings),
          productionStatus: cow.productionStatus.code,
          updatedAt: _now(),
          syncPending: const Value(true),
          syncError: const Value(null),
          isDemo: Value(isDemo || cow.isDemo),
        ),
      );

  @override
  Future<void> deleteCow(String id) => (db.update(db.cows)..where((c) => c.id.equals(id))).write(
    CowsCompanion(
      deleted: const Value(true),
      updatedAt: Value(_now()),
      syncPending: const Value(true),
      syncError: const Value(null),
    ),
  );

  @override
  Future<bool> isTagInUse(String tag, {String? exceptId}) async {
    final query = db.select(db.cows)..where((c) => c.tag.equals(tag.trim()) & c.deleted.equals(false));
    if (exceptId != null) query.where((c) => c.id.equals(exceptId).not());
    return (await query.get()).isNotEmpty;
  }

  Cow _toCow(CowRow row) => Cow(
    id: row.id,
    tag: row.tag,
    name: row.name,
    breed: row.breed,
    birthDate: row.birthDate,
    calvings: row.calvings,
    productionStatus: ProductionStatus.fromCode(row.productionStatus),
    updatedAt: row.updatedAt,
    isDemo: row.isDemo,
  );

  // ---- Registros diarios ----

  @override
  Future<DailyRecord?> recordFor(String cowId, DateTime date) async {
    final row =
        await (db.select(db.dailyRecords)..where(
              (r) => r.cowId.equals(cowId) & r.recordDate.equals(dateKey(date)) & r.deleted.equals(false),
            ))
            .getSingleOrNull();
    return row == null ? null : _toRecord(row);
  }

  @override
  Future<void> saveRecord(DailyRecord record) => db
      .into(db.dailyRecords)
      .insertOnConflictUpdate(
        DailyRecordsCompanion.insert(
          id: record.id,
          cowId: record.cowId,
          recordDate: dateKey(record.recordDate),
          temperatureC: Value(record.temperatureC),
          milkL: Value(record.milkL),
          feedKg: Value(record.feedKg),
          udderSwelling: Value(record.symptoms.udderSwelling),
          abnormalMilk: Value(record.symptoms.abnormalMilk),
          udderPain: Value(record.symptoms.udderPain),
          lethargy: Value(record.symptoms.lethargy),
          notes: Value(record.notes),
          updatedAt: _now(),
          syncPending: const Value(true),
          syncError: const Value(null),
          isDemo: Value(isDemo),
        ),
      );

  @override
  Future<List<DailyRecord>> recordsBetween(String cowId, DateTime from, DateTime to) async {
    final rows =
        await (db.select(db.dailyRecords)
              ..where(
                (r) =>
                    r.cowId.equals(cowId) &
                    r.deleted.equals(false) &
                    r.recordDate.isBetweenValues(dateKey(from), dateKey(to)),
              )
              ..orderBy([(r) => OrderingTerm.asc(r.recordDate)]))
            .get();
    return rows.map(_toRecord).toList();
  }

  DailyRecord _toRecord(DailyRecordRow row) => DailyRecord(
    id: row.id,
    cowId: row.cowId,
    recordDate: parseDateKey(row.recordDate),
    temperatureC: row.temperatureC,
    milkL: row.milkL,
    feedKg: row.feedKg,
    symptoms: Symptoms(
      udderSwelling: row.udderSwelling,
      abnormalMilk: row.abnormalMilk,
      udderPain: row.udderPain,
      lethargy: row.lethargy,
    ),
    notes: row.notes,
    updatedAt: row.updatedAt,
  );

  // ---- Inferencias y alertas ----

  @override
  Future<void> saveInference(Inference inference, {CowAlert? alert}) => db.transaction(() async {
    await db
        .into(db.inferences)
        .insertOnConflictUpdate(
          InferencesCompanion.insert(
            id: inference.id,
            cowId: inference.cowId,
            windowEndDate: dateKey(inference.windowEndDate),
            probability: inference.probability,
            riskLevel: inference.riskLevel.code,
            modelVersion: inference.modelVersion,
            updatedAt: _now(),
            syncPending: const Value(true),
            syncError: const Value(null),
            isDemo: Value(isDemo),
          ),
        );
    if (alert != null) {
      await db
          .into(db.alerts)
          .insertOnConflictUpdate(
            AlertsCompanion.insert(
              id: alert.id,
              cowId: alert.cowId,
              inferenceId: Value(alert.inferenceId),
              riskLevel: alert.riskLevel.code,
              createdAt: alert.createdAt,
              updatedAt: _now(),
              syncPending: const Value(true),
              syncError: const Value(null),
              isDemo: Value(isDemo),
            ),
          );
    }
  });

  @override
  Stream<Inference?> watchLatest(String cowId) =>
      (db.select(db.inferences)
            ..where((i) => i.cowId.equals(cowId) & i.deleted.equals(false))
            ..orderBy([(i) => OrderingTerm.desc(i.windowEndDate), (i) => OrderingTerm.desc(i.updatedAt)])
            ..limit(1))
          .watchSingleOrNull()
          .map((row) => row == null ? null : _toInference(row));

  @override
  Future<List<Inference>> inferencesBetween(String cowId, DateTime from, DateTime to) async {
    final rows =
        await (db.select(db.inferences)
              ..where(
                (i) =>
                    i.cowId.equals(cowId) &
                    i.deleted.equals(false) &
                    i.windowEndDate.isBetweenValues(dateKey(from), dateKey(to)),
              )
              ..orderBy([(i) => OrderingTerm.asc(i.windowEndDate), (i) => OrderingTerm.asc(i.updatedAt)]))
            .get();
    return rows.map(_toInference).toList();
  }

  Inference _toInference(InferenceRow row) => Inference(
    id: row.id,
    cowId: row.cowId,
    windowEndDate: parseDateKey(row.windowEndDate),
    probability: row.probability,
    riskLevel: RiskLevel.fromCode(row.riskLevel),
    modelVersion: row.modelVersion,
    updatedAt: row.updatedAt,
  );

  @override
  Stream<List<CowAlert>> watchPendingAlerts(String cowId) =>
      (db.select(db.alerts)
            ..where((a) => a.cowId.equals(cowId) & a.attended.equals(false) & a.deleted.equals(false))
            ..orderBy([(a) => OrderingTerm.desc(a.createdAt)]))
          .watch()
          .map((rows) => rows.map(_toAlert).toList());

  @override
  Future<void> markAlertAttended(String alertId) {
    final now = _now();
    // Solo cambia si seguía sin atender: tocar dos veces no genera otra versión para sincronizar
    return (db.update(db.alerts)..where((a) => a.id.equals(alertId) & a.attended.equals(false))).write(
      AlertsCompanion(
        attended: const Value(true),
        attendedAt: Value(now),
        updatedAt: Value(now),
        syncPending: const Value(true),
        syncError: const Value(null),
      ),
    );
  }

  CowAlert _toAlert(AlertRow row) => CowAlert(
    id: row.id,
    cowId: row.cowId,
    inferenceId: row.inferenceId,
    riskLevel: RiskLevel.fromCode(row.riskLevel),
    attended: row.attended,
    attendedAt: row.attendedAt,
    createdAt: row.createdAt,
  );
}
