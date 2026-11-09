import 'package:drift/drift.dart';

import '../local/app_database.dart';
import '../local/local_repository.dart';
import '../remote/api_client.dart';

/// Lectura de los datos del ganadero en el servidor; separada para probar sin red.
abstract interface class RestoreGateway {
  /// GET /api/cows: vacas activas.
  Future<List<Map<String, dynamic>>> fetchCows();

  /// GET /api/cows/{id}/history: registros, evaluaciones y alertas entre dos fechas.
  Future<Map<String, dynamic>> fetchHistory(String cowId, DateTime from, DateTime to);
}

class RestoreApi implements RestoreGateway {
  RestoreApi(this._client);

  final ApiClient _client;

  @override
  Future<List<Map<String, dynamic>>> fetchCows() async {
    final response = await _client.dio.get<List<dynamic>>('/api/cows');
    return (response.data ?? const []).cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>> fetchHistory(String cowId, DateTime from, DateTime to) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/api/cows/$cowId/history',
      queryParameters: {'from': dateKey(from), 'to': dateKey(to)},
    );
    return response.data!;
  }
}

/// Resultado de una restauración, para mostrarlo o registrarlo.
class RestoreReport {
  const RestoreReport({this.cows = 0, this.records = 0, this.inferences = 0, this.alerts = 0, this.error});

  final int cows;
  final int records;
  final int inferences;
  final int alerts;

  /// Mensaje para el usuario si no se pudo terminar; lo ya guardado se conserva.
  final String? error;

  bool get ok => error == null;
}

/// Trae del servidor los datos del ganadero cuando entra en un celular sin sus vacas (celular nuevo,
/// app reinstalada o datos borrados).
///
/// - Solo actúa si la base local no tiene ninguna vaca real: así nunca compite con cambios hechos en
///   este celular.
/// - Inserta sin sobrescribir (si el id ya existe, gana lo local) y marca todo como ya sincronizado,
///   para que no se vuelva a subir.
/// - Trae el último año de historial (el servidor admite hasta 366 días por consulta).
/// - Las fotos no se restauran: el servidor guarda los archivos, pero no hay forma de listarlos.
class RestoreService {
  RestoreService(this.db, this.gateway, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final AppDatabase db;
  final RestoreGateway gateway;
  final DateTime Function() _now;

  static const historyDays = 365;

  Future<bool> localIsEmpty() async {
    final count = db.cows.id.count();
    final query = db.selectOnly(db.cows)
      ..addColumns([count])
      ..where(db.cows.isDemo.equals(false));
    return (await query.getSingle()).read(count) == 0;
  }

  /// Restaura si la base local está vacía; si no, no hace nada.
  Future<RestoreReport> restoreIfEmpty() async {
    if (!await localIsEmpty()) return const RestoreReport();
    try {
      return await _restore();
    } catch (e) {
      return RestoreReport(error: ApiClient.describe(e).message);
    }
  }

  Future<RestoreReport> _restore() async {
    final now = _now();
    final to = DateTime(now.year, now.month, now.day);
    final from = to.subtract(const Duration(days: historyDays));
    final cows = await gateway.fetchCows();
    // Se piden todos los historiales antes de escribir: si falla la red a mitad, no queda nada a medias
    final histories = <Map<String, dynamic>>[
      for (final cow in cows) await gateway.fetchHistory(cow['id'] as String, from, to),
    ];
    List<Map<String, dynamic>> items(Map<String, dynamic> history, String key) =>
        (history[key] as List? ?? const []).cast<Map<String, dynamic>>();
    var records = 0, inferences = 0, alerts = 0;
    await db.transaction(() async {
      // Primero las vacas y las evaluaciones: los registros y las alertas apuntan a ellas
      for (final cow in cows) {
        await db.into(db.cows).insert(_cow(cow, now), mode: InsertMode.insertOrIgnore);
      }
      for (var i = 0; i < cows.length; i++) {
        final cowId = cows[i]['id'] as String;
        final history = histories[i];
        for (final r in items(history, 'records')) {
          await db.into(db.dailyRecords).insert(_record(cowId, r, now), mode: InsertMode.insertOrIgnore);
          records++;
        }
        for (final inf in items(history, 'inferences')) {
          await db.into(db.inferences).insert(_inference(cowId, inf, now), mode: InsertMode.insertOrIgnore);
          inferences++;
        }
        // Una alerta cuya evaluación quedó fuera del año traído se guarda sin ese vínculo
        final known = {for (final inf in items(history, 'inferences')) inf['id'] as String};
        for (final a in items(history, 'alerts')) {
          final linked = known.contains(a['inferenceId']) ? a : {...a, 'inferenceId': null};
          await db.into(db.alerts).insert(_alert(cowId, linked, now), mode: InsertMode.insertOrIgnore);
          alerts++;
        }
      }
    });
    // Cantidades recibidas del servidor
    return RestoreReport(cows: cows.length, records: records, inferences: inferences, alerts: alerts);
  }

  static DateTime? _date(Object? value) => value == null ? null : DateTime.parse(value as String);

  static DateTime? _instant(Object? value) => value == null ? null : DateTime.parse(value as String).toLocal();

  static CowsCompanion _cow(Map<String, dynamic> c, DateTime now) => CowsCompanion.insert(
        id: c['id'] as String,
        tag: c['tag'] as String,
        name: Value(c['name'] as String?),
        breed: Value(c['breed'] as String?),
        birthDate: Value(_date(c['birthDate'])),
        calvings: Value(c['calvings'] as int?),
        productionStatus: c['productionStatus'] as String,
        updatedAt: _instant(c['updatedAt']) ?? now,
        syncPending: const Value(false),
      );

  static DailyRecordsCompanion _record(String cowId, Map<String, dynamic> r, DateTime now) {
    final symptoms = r['symptoms'] as Map<String, dynamic>? ?? const {};
    final sources = r['sources'] as Map<String, dynamic>? ?? const {};
    bool flag(String key) => symptoms[key] as bool? ?? false;
    return DailyRecordsCompanion.insert(
      id: r['id'] as String,
      cowId: cowId,
      recordDate: r['recordDate'] as String,
      temperatureC: Value((r['temperatureC'] as num?)?.toDouble()),
      milkL: Value((r['milkL'] as num?)?.toDouble()),
      feedKg: Value((r['feedKg'] as num?)?.toDouble()),
      temperatureSource: Value(sources['temperature'] as String?),
      milkSource: Value(sources['milk'] as String?),
      feedSource: Value(sources['feed'] as String?),
      udderSwelling: Value(flag('udderSwelling')),
      abnormalMilk: Value(flag('abnormalMilk')),
      udderPain: Value(flag('udderPain')),
      lethargy: Value(flag('lethargy')),
      udderRedness: Value(flag('udderRedness')),
      udderHeat: Value(flag('udderHeat')),
      ateNormally: Value(symptoms['ateNormally'] as bool?),
      milkDrop: Value(symptoms['milkDrop'] as bool?),
      notes: Value(r['notes'] as String?),
      updatedAt: now,
      syncPending: const Value(false),
    );
  }

  static InferencesCompanion _inference(String cowId, Map<String, dynamic> i, DateTime now) =>
      InferencesCompanion.insert(
        id: i['id'] as String,
        cowId: cowId,
        windowEndDate: i['windowEndDate'] as String,
        probability: Value((i['probability'] as num?)?.toDouble()),
        symptomScore: Value(i['symptomScore'] as int?),
        cause: Value(i['cause'] as String?),
        riskLevel: i['riskLevel'] as String,
        modelVersion: i['modelVersion'] as String,
        updatedAt: now,
        syncPending: const Value(false),
      );

  static AlertsCompanion _alert(String cowId, Map<String, dynamic> a, DateTime now) => AlertsCompanion.insert(
        id: a['id'] as String,
        cowId: cowId,
        inferenceId: Value(a['inferenceId'] as String?),
        riskLevel: a['riskLevel'] as String,
        attended: Value(a['attended'] as bool? ?? false),
        attendedAt: Value(_instant(a['attendedAt'])),
        createdAt: _instant(a['createdAt']) ?? now,
        updatedAt: now,
        syncPending: const Value(false),
      );
}
