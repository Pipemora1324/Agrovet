import 'dart:math';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../local/app_database.dart';
import '../local/local_repository.dart';
import '../remote/api_client.dart';

/// Respuesta del servidor: ids confirmados por tipo y elementos rechazados con su motivo.
class SyncResponse {
  const SyncResponse({required this.confirmed, required this.rejected});

  factory SyncResponse.fromJson(Map<String, dynamic> json) {
    final confirmed = json['confirmed'] as Map<String, dynamic>;
    return SyncResponse(
      confirmed: {
        for (final entry in confirmed.entries) entry.key: (entry.value as List).cast<String>().toSet(),
      },
      rejected: {
        for (final item in (json['rejected'] as List).cast<Map<String, dynamic>>())
          item['id'] as String: item['reason'] as String,
      },
    );
  }

  final Map<String, Set<String>> confirmed;
  final Map<String, String> rejected;
}

/// Envío del lote al servidor; separado para poder probar el servicio sin red.
abstract interface class SyncGateway {
  Future<SyncResponse> send(Map<String, dynamic> batch);
}

class SyncApi implements SyncGateway {
  SyncApi(this._client);

  final ApiClient _client;

  @override
  Future<SyncResponse> send(Map<String, dynamic> batch) async {
    final response = await _client.dio.post<Map<String, dynamic>>('/api/sync', data: batch);
    return SyncResponse.fromJson(response.data!);
  }
}

/// Elemento que el servidor no aceptó; se muestra al ganadero para que lo corrija.
class SyncIssue {
  const SyncIssue({required this.kind, required this.label, required this.reason});

  /// Qué es, en palabras del ganadero: "Vaca", "Registro", "Evaluación" o "Alerta".
  final String kind;

  /// Arete de la vaca y, si aplica, el día.
  final String label;
  final String reason;
}

class SyncReport {
  const SyncReport({this.sent = 0, this.confirmed = 0, this.rejected = 0, this.error});

  final int sent;
  final int confirmed;
  final int rejected;

  /// Mensaje para el usuario si no se pudo terminar (los datos siguen guardados en el celular).
  final String? error;

  bool get ok => error == null;
}

/// Sube los cambios pendientes de la base local.
///
/// - Primero vacas, luego registros, inferencias y alertas, para que el servidor encuentre la vaca.
/// - Solo se marca como sincronizado lo que el servidor confirma, y solo si la fila no cambió
///   mientras se enviaba (si cambió, queda pendiente para el siguiente envío).
/// - Nunca se borra nada local.
/// - Ante fallas de red o del servidor se reintenta con espera exponencial.
/// - Los datos de demostración no se envían nunca.
class SyncService {
  SyncService(
    this.db,
    this.gateway, {
    this.batchSize = 200,
    this.maxAttempts = 4,
    this.baseDelay = const Duration(seconds: 2),
    Future<void> Function(Duration)? sleep,
    Random? random,
  })  : _sleep = sleep ?? Future<void>.delayed,
        _random = random ?? Random();

  final AppDatabase db;
  final SyncGateway gateway;
  final int batchSize;
  final int maxAttempts;
  final Duration baseDelay;
  final Future<void> Function(Duration) _sleep;
  final Random _random;

  static const _maxRounds = 20;

  /// Cantidad de cambios que faltan por subir.
  Stream<int> watchPendingCount() {
    final query = db.customSelect(
      'SELECT '
      '(SELECT count(*) FROM cows WHERE sync_pending = 1 AND is_demo = 0) + '
      '(SELECT count(*) FROM daily_records WHERE sync_pending = 1 AND is_demo = 0) + '
      '(SELECT count(*) FROM inferences WHERE sync_pending = 1 AND is_demo = 0) + '
      '(SELECT count(*) FROM alerts WHERE sync_pending = 1 AND is_demo = 0) AS pending',
      readsFrom: {db.cows, db.dailyRecords, db.inferences, db.alerts},
    );
    return query.watchSingle().map((row) => row.read<int>('pending'));
  }

  /// Lo rechazado por el servidor (queda con su motivo hasta que el ganadero lo corrija).
  Stream<List<SyncIssue>> watchRejected() {
    final query = db.customSelect(
      "SELECT 'Vaca' AS kind, tag AS label, sync_error FROM cows "
      'WHERE sync_error IS NOT NULL AND is_demo = 0 '
      "UNION ALL SELECT 'Registro', c.tag || ' · ' || d.record_date, d.sync_error FROM daily_records d "
      'JOIN cows c ON c.id = d.cow_id WHERE d.sync_error IS NOT NULL AND d.is_demo = 0 '
      "UNION ALL SELECT 'Evaluación', c.tag || ' · ' || i.window_end_date, i.sync_error FROM inferences i "
      'JOIN cows c ON c.id = i.cow_id WHERE i.sync_error IS NOT NULL AND i.is_demo = 0 '
      "UNION ALL SELECT 'Alerta', c.tag, a.sync_error FROM alerts a "
      'JOIN cows c ON c.id = a.cow_id WHERE a.sync_error IS NOT NULL AND a.is_demo = 0',
      readsFrom: {db.cows, db.dailyRecords, db.inferences, db.alerts},
    );
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          SyncIssue(
            kind: row.read<String>('kind'),
            label: row.read<String>('label'),
            reason: row.read<String>('sync_error'),
          ),
      ],
    );
  }

  Future<SyncReport> syncNow() async {
    var sent = 0, confirmed = 0, rejected = 0;
    for (var round = 0; round < _maxRounds; round++) {
      final batch = await _collect();
      if (batch.isEmpty) break;
      final SyncResponse response;
      try {
        response = await _sendWithRetry(batch.payload);
      } on ApiException catch (e) {
        return SyncReport(sent: sent, confirmed: confirmed, rejected: rejected, error: e.message);
      }
      sent += batch.size;
      final result = await _apply(batch, response);
      confirmed += result.confirmed;
      rejected += result.rejected;
      // Si nada avanzó (todo cambió mientras se enviaba), se deja para el próximo intento
      if (result.confirmed + result.rejected == 0) break;
    }
    return SyncReport(sent: sent, confirmed: confirmed, rejected: rejected);
  }

  Future<SyncResponse> _sendWithRetry(Map<String, dynamic> payload) async {
    for (var attempt = 1;; attempt++) {
      try {
        return await gateway.send(payload);
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        final retriable = status == null || status >= 500;
        if (!retriable || attempt >= maxAttempts) throw ApiClient.describe(e);
        // 2 s, 4 s, 8 s… con ±20 % de variación para no saturar el servidor al volver la señal
        final factor = 0.8 + _random.nextDouble() * 0.4;
        await _sleep(baseDelay * (pow(2, attempt - 1) * factor));
      }
    }
  }

  Future<_Batch> _collect() async {
    final cows = await (db.select(db.cows)
          ..where((t) => t.syncPending.equals(true) & t.isDemo.equals(false))
          ..limit(batchSize))
        .get();
    final records = await (db.select(db.dailyRecords)
          ..where((t) => t.syncPending.equals(true) & t.isDemo.equals(false))
          ..limit(batchSize))
        .get();
    final inferences = await (db.select(db.inferences)
          ..where((t) => t.syncPending.equals(true) & t.isDemo.equals(false))
          ..limit(batchSize))
        .get();
    final alerts = await (db.select(db.alerts)
          ..where((t) => t.syncPending.equals(true) & t.isDemo.equals(false))
          ..limit(batchSize))
        .get();
    return _Batch(cows, records, inferences, alerts);
  }

  Future<({int confirmed, int rejected})> _apply(_Batch batch, SyncResponse response) async {
    var confirmed = 0, rejected = 0;
    await db.transaction(() async {
      // El nombre de la tabla es una constante del código; los valores van como parámetros
      Future<void> mark(TableInfo<Table, dynamic> table, String entity,
          Iterable<({String id, DateTime updatedAt})> rows) async {
        final ok = response.confirmed[entity] ?? const <String>{};
        for (final row in rows) {
          final reason = response.rejected[row.id];
          if (!ok.contains(row.id) && reason == null) continue;
          final changed = await db.customUpdate(
            'UPDATE ${table.actualTableName} SET sync_pending = 0, sync_error = ? '
            'WHERE id = ? AND updated_at = ?',
            variables: [Variable<String>(reason), Variable<String>(row.id), Variable<DateTime>(row.updatedAt)],
            updates: {table},
          );
          if (changed > 0) reason == null ? confirmed++ : rejected++;
        }
      }

      await mark(db.cows, 'cows', batch.cows.map((r) => (id: r.id, updatedAt: r.updatedAt)));
      await mark(db.dailyRecords, 'dailyRecords', batch.records.map((r) => (id: r.id, updatedAt: r.updatedAt)));
      await mark(db.inferences, 'inferences', batch.inferences.map((r) => (id: r.id, updatedAt: r.updatedAt)));
      await mark(db.alerts, 'alerts', batch.alerts.map((r) => (id: r.id, updatedAt: r.updatedAt)));
    });
    return (confirmed: confirmed, rejected: rejected);
  }
}

class _Batch {
  _Batch(this.cows, this.records, this.inferences, this.alerts);

  final List<CowRow> cows;
  final List<DailyRecordRow> records;
  final List<InferenceRow> inferences;
  final List<AlertRow> alerts;

  int get size => cows.length + records.length + inferences.length + alerts.length;

  bool get isEmpty => size == 0;

  static String _instant(DateTime value) => value.toUtc().toIso8601String();

  /// Mismos nombres de campo que espera POST /api/sync.
  Map<String, dynamic> get payload => {
        'cows': [
          for (final c in cows)
            {
              'id': c.id,
              'tag': c.tag,
              'name': c.name,
              'breed': c.breed,
              'birthDate': c.birthDate == null ? null : dateKey(c.birthDate!),
              'calvings': c.calvings,
              'productionStatus': c.productionStatus,
              'updatedAt': _instant(c.updatedAt),
              'deleted': c.deleted,
            },
        ],
        'dailyRecords': [
          for (final r in records)
            {
              'id': r.id,
              'cowId': r.cowId,
              'recordDate': r.recordDate,
              'temperatureC': r.temperatureC,
              'milkL': r.milkL,
              'feedKg': r.feedKg,
              'udderSwelling': r.udderSwelling,
              'abnormalMilk': r.abnormalMilk,
              'udderPain': r.udderPain,
              'lethargy': r.lethargy,
              'notes': r.notes,
              'updatedAt': _instant(r.updatedAt),
              'deleted': r.deleted,
            },
        ],
        'inferences': [
          for (final i in inferences)
            {
              'id': i.id,
              'cowId': i.cowId,
              'windowEndDate': i.windowEndDate,
              'probability': i.probability,
              'riskLevel': i.riskLevel,
              'modelVersion': i.modelVersion,
              'updatedAt': _instant(i.updatedAt),
              'deleted': i.deleted,
            },
        ],
        'alerts': [
          for (final a in alerts)
            {
              'id': a.id,
              'cowId': a.cowId,
              'inferenceId': a.inferenceId,
              'riskLevel': a.riskLevel,
              'attended': a.attended,
              'attendedAt': a.attendedAt == null ? null : _instant(a.attendedAt!),
              'updatedAt': _instant(a.updatedAt),
              'deleted': a.deleted,
            },
        ],
      };
}
