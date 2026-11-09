import 'package:agrovet/data/local/app_database.dart';
import 'package:agrovet/data/local/local_repository.dart';
import 'package:agrovet/data/sync/restore_service.dart';
import 'package:agrovet/data/sync/sync_service.dart';
import 'package:agrovet/domain/entities.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Servidor simulado con lo que devuelven GET /api/cows y GET /api/cows/{id}/history.
class FakeRestoreGateway implements RestoreGateway {
  FakeRestoreGateway({this.cows = const [], this.histories = const {}, this.failHistory = false});

  final List<Map<String, dynamic>> cows;
  final Map<String, Map<String, dynamic>> histories;
  final bool failHistory;
  int calls = 0;
  ({DateTime from, DateTime to})? lastRange;

  @override
  Future<List<Map<String, dynamic>>> fetchCows() async {
    calls++;
    return cows;
  }

  @override
  Future<Map<String, dynamic>> fetchHistory(String cowId, DateTime from, DateTime to) async {
    calls++;
    lastRange = (from: from, to: to);
    if (failHistory) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/cows/$cowId/history'),
        type: DioExceptionType.connectionError,
      );
    }
    return histories[cowId] ?? {'records': [], 'inferences': [], 'alerts': []};
  }
}

void main() {
  late AppDatabase db;
  final today = DateTime(2026, 11, 9, 15);

  const cow = {
    'id': 'c1',
    'tag': 'F-101',
    'name': 'Manchas',
    'breed': 'Holstein',
    'birthDate': null,
    'calvings': 2,
    'productionStatus': 'LACTATING',
    'updatedAt': '2026-11-09T20:31:00Z',
  };
  final history = {
    'records': [
      {
        'id': 'r1',
        'recordDate': '2026-11-09',
        'temperatureC': 39.1,
        'milkL': 11.7,
        'feedKg': 9.4,
        'symptoms': {
          'udderSwelling': true,
          'abnormalMilk': false,
          'udderPain': false,
          'lethargy': false,
          'udderRedness': false,
          'udderHeat': false,
          'ateNormally': false,
          'milkDrop': true,
        },
        'sources': {'temperature': 'estimated', 'milk': 'estimated', 'feed': 'estimated'},
        'notes': null,
      },
    ],
    'inferences': [
      {
        'id': 'i1',
        'windowEndDate': '2026-11-09',
        'probability': null,
        'symptomScore': 4,
        'cause': 'SYMPTOMS',
        'riskLevel': 'RED',
        'modelVersion': 'lstm-v1',
      },
    ],
    'alerts': [
      {
        'id': 'a1',
        'inferenceId': 'i1',
        'riskLevel': 'RED',
        'attended': false,
        'attendedAt': null,
        'createdAt': '2026-11-09T20:44:00Z',
      },
    ],
  };

  RestoreService service(RestoreGateway gateway) => RestoreService(db, gateway, clock: () => today);

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  test('en un celular vacío trae las vacas y su historial, ya sincronizados', () async {
    final gateway = FakeRestoreGateway(cows: [cow], histories: {'c1': history});

    final report = await service(gateway).restoreIfEmpty();

    expect(report.ok, isTrue);
    expect((report.cows, report.records, report.inferences, report.alerts), (1, 1, 1, 1));
    final cowRow = await db.select(db.cows).getSingle();
    expect((cowRow.tag, cowRow.name, cowRow.calvings, cowRow.syncPending), ('F-101', 'Manchas', 2, false));
    final record = await db.select(db.dailyRecords).getSingle();
    expect(record.recordDate, '2026-11-09');
    expect(record.udderSwelling, isTrue);
    expect(record.ateNormally, isFalse);
    expect(record.milkDrop, isTrue);
    expect(record.temperatureSource, 'estimated');
    expect(record.syncPending, isFalse);
    expect((await db.select(db.inferences).getSingle()).symptomScore, 4);
    expect((await db.select(db.alerts).getSingle()).inferenceId, 'i1');
    // Nada queda pendiente: no se vuelve a subir lo que vino del servidor
    expect(await SyncService(db, _NoGateway()).watchPendingCount().first, 0);
    // Último año de historial
    expect(gateway.lastRange!.to, DateTime(2026, 11, 9));
    expect(gateway.lastRange!.from, DateTime(2026, 11, 9).subtract(const Duration(days: 365)));
  });

  test('si el celular ya tiene vacas no consulta al servidor ni toca nada', () async {
    await LocalRepository(db).saveCow(
      Cow(id: 'local', tag: 'L-1', productionStatus: ProductionStatus.dry, updatedAt: today),
    );
    final gateway = FakeRestoreGateway(cows: [cow], histories: {'c1': history});

    final report = await service(gateway).restoreIfEmpty();

    expect(report.ok, isTrue);
    expect(gateway.calls, 0);
    expect((await db.select(db.cows).get()).map((c) => c.id), ['local']);
  });

  test('si la red falla a mitad no deja datos a medias y avisa en español', () async {
    final gateway = FakeRestoreGateway(cows: [cow], failHistory: true);

    final report = await service(gateway).restoreIfEmpty();

    expect(report.ok, isFalse);
    expect(report.error, contains('servidor de AgroVet'));
    expect(await db.select(db.cows).get(), isEmpty);
    expect(await service(gateway).localIsEmpty(), isTrue);
  });

  test('una alerta cuya evaluación quedó fuera del año se guarda sin ese vínculo', () async {
    final gateway = FakeRestoreGateway(cows: [cow], histories: {
      'c1': {
        'records': [],
        'inferences': [],
        'alerts': [
          {'id': 'a9', 'inferenceId': 'vieja', 'riskLevel': 'YELLOW', 'attended': true,
            'attendedAt': '2026-01-02T10:00:00Z', 'createdAt': '2026-01-01T10:00:00Z'},
        ],
      },
    });

    expect((await service(gateway).restoreIfEmpty()).ok, isTrue);
    final alert = await db.select(db.alerts).getSingle();
    expect((alert.inferenceId, alert.attended, alert.syncPending), (null, true, false));
  });
}

class _NoGateway implements SyncGateway {
  @override
  Future<SyncResponse> send(Map<String, dynamic> batch) => throw UnimplementedError();

  @override
  Future<void> uploadPhoto({required String cowId, required String photoId, required List<int> jpeg}) =>
      throw UnimplementedError();
}
