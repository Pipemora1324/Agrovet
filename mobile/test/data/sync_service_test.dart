import 'package:agrovet/data/local/app_database.dart';
import 'package:agrovet/data/local/local_repository.dart';
import 'package:agrovet/data/sync/sync_service.dart';
import 'package:agrovet/domain/entities.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Servidor simulado: confirma todo salvo los ids indicados, o falla las primeras veces.
class FakeGateway implements SyncGateway {
  FakeGateway({this.reject = const {}, this.failures = 0, this.failWith, this.beforeAnswer});

  final Map<String, String> reject;
  int failures;
  final int? failWith;
  final Future<void> Function()? beforeAnswer;
  final List<Map<String, dynamic>> batches = [];

  @override
  Future<SyncResponse> send(Map<String, dynamic> batch) async {
    batches.add(batch);
    if (failures > 0) {
      failures--;
      final request = RequestOptions(path: '/api/sync');
      throw DioException(
        requestOptions: request,
        response: failWith == null ? null : Response(requestOptions: request, statusCode: failWith),
        type: failWith == null ? DioExceptionType.connectionError : DioExceptionType.badResponse,
      );
    }
    await beforeAnswer?.call();
    Set<String> ids(String key) =>
        {for (final item in batch[key] as List) (item as Map)['id'] as String}..removeAll(reject.keys);
    return SyncResponse(
      confirmed: {for (final key in ['cows', 'dailyRecords', 'inferences', 'alerts']) key: ids(key)},
      rejected: reject,
    );
  }
}

void main() {
  late AppDatabase db;
  late LocalRepository repo;
  late List<Duration> waits;
  final day = DateTime(2026, 3, 20);

  SyncService service(SyncGateway gateway) => SyncService(db, gateway, sleep: (d) async => waits.add(d));

  Future<void> seed() async {
    await repo.saveCow(Cow(id: 'c1', tag: 'V-01', productionStatus: ProductionStatus.lactating, updatedAt: day));
    await repo.saveRecord(DailyRecord(id: 'r1', cowId: 'c1', recordDate: day, milkL: 12, updatedAt: day));
  }

  setUp(() {
    db = memoryDatabase();
    repo = LocalRepository(db);
    waits = [];
  });

  tearDown(() => db.close());

  test('envía lo pendiente y lo marca como sincronizado solo tras la confirmación', () async {
    await seed();
    final gateway = FakeGateway();
    expect(await service(gateway).watchPendingCount().first, 2);

    final report = await service(gateway).syncNow();

    expect(report.ok, isTrue);
    expect(report.confirmed, 2);
    expect(gateway.batches, hasLength(1));
    final sentCow = (gateway.batches.single['cows'] as List).single as Map;
    expect(sentCow['tag'], 'V-01');
    expect(sentCow['productionStatus'], 'LACTATING');
    expect((gateway.batches.single['dailyRecords'] as List).single['recordDate'], '2026-03-20');
    expect(await service(gateway).watchPendingCount().first, 0);
    // Nada local se borró
    expect(await db.select(db.cows).get(), hasLength(1));
  });

  test('sin cambios pendientes no llama al servidor', () async {
    final gateway = FakeGateway();
    final report = await service(gateway).syncNow();
    expect(report.sent, 0);
    expect(gateway.batches, isEmpty);
  });

  test('una fila editada mientras viajaba el lote queda pendiente', () async {
    await seed();
    final gateway = FakeGateway(beforeAnswer: () async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.saveRecord(DailyRecord(id: 'r1', cowId: 'c1', recordDate: day, milkL: 9, updatedAt: day));
    });
    await service(gateway).syncNow();
    final record = await db.select(db.dailyRecords).getSingle();
    expect(record.syncPending, isTrue);
    expect(record.milkL, 9);
    expect((await db.select(db.cows).getSingle()).syncPending, isFalse);
  });

  test('lo rechazado queda marcado con el motivo y no se reintenta sin cambios', () async {
    await seed();
    final gateway = FakeGateway(reject: {'r1': 'Ya existe otro registro de esa vaca para ese día.'});
    final report = await service(gateway).syncNow();
    expect(report.rejected, 1);
    final record = await db.select(db.dailyRecords).getSingle();
    expect(record.syncPending, isFalse);
    expect(record.syncError, 'Ya existe otro registro de esa vaca para ese día.');

    // Al corregirlo vuelve a quedar pendiente y sin el error
    await repo.saveRecord(DailyRecord(id: 'r1', cowId: 'c1', recordDate: day, milkL: 11, updatedAt: day));
    final edited = await db.select(db.dailyRecords).getSingle();
    expect(edited.syncPending, isTrue);
    expect(edited.syncError, isNull);
  });

  test('sin red reintenta con espera exponencial y luego confirma', () async {
    await seed();
    final gateway = FakeGateway(failures: 2);
    final report = await service(gateway).syncNow();
    expect(report.ok, isTrue);
    expect(gateway.batches, hasLength(3));
    expect(waits, hasLength(2));
    expect(waits[0].inMilliseconds, inInclusiveRange(1600, 2400));
    expect(waits[1].inMilliseconds, inInclusiveRange(3200, 4800));
  });

  test('si la red no vuelve, se rinde sin marcar nada como sincronizado', () async {
    await seed();
    final gateway = FakeGateway(failures: 10);
    final report = await service(gateway).syncNow();
    expect(report.ok, isFalse);
    expect(report.error, contains('No hay conexión'));
    expect(gateway.batches, hasLength(4));
    expect(await service(gateway).watchPendingCount().first, 2);
  });

  test('un error 400 del servidor no se reintenta', () async {
    await seed();
    final gateway = FakeGateway(failures: 1, failWith: 400);
    final report = await service(gateway).syncNow();
    expect(report.ok, isFalse);
    expect(gateway.batches, hasLength(1));
    expect(waits, isEmpty);
  });

  test('los datos de demostración nunca se envían', () async {
    final demo = LocalRepository(db, isDemo: true);
    await demo.saveCow(Cow(id: 'd1', tag: 'DEMO-01', productionStatus: ProductionStatus.lactating, updatedAt: day));
    final gateway = FakeGateway();
    await service(gateway).syncNow();
    expect(gateway.batches, isEmpty);
    expect(await service(gateway).watchPendingCount().first, 0);
  });

  test('envía en lotes del tamaño configurado', () async {
    for (var i = 0; i < 5; i++) {
      await repo.saveCow(Cow(id: 'c$i', tag: 'V-$i', productionStatus: ProductionStatus.dry, updatedAt: day));
    }
    final gateway = FakeGateway();
    await SyncService(db, gateway, batchSize: 2, sleep: (_) async {}).syncNow();
    expect(gateway.batches.map((b) => (b['cows'] as List).length), [2, 2, 1]);
  });
}
