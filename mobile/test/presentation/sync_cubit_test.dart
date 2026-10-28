import 'dart:async';

import 'package:agrovet/data/local/app_database.dart';
import 'package:agrovet/data/local/local_repository.dart';
import 'package:agrovet/data/sync/sync_service.dart';
import 'package:agrovet/domain/entities.dart';
import 'package:agrovet/presentation/sync/sync_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/sync_service_test.dart' show FakeGateway;
import '../helpers.dart';

void main() {
  test('al recuperar la conexión sube lo pendiente', () async {
    final db = memoryDatabase();
    final repo = LocalRepository(db);
    await repo.saveCow(Cow(id: 'c1', tag: 'V-01', productionStatus: ProductionStatus.lactating, updatedAt: DateTime(2026)));
    final gateway = FakeGateway();
    final online = StreamController<bool>();
    final cubit = SyncCubit(SyncService(db, gateway, sleep: (_) async {}), connectivity: online.stream);

    await expectLater(cubit.stream, emitsThrough(predicate<SyncState>((s) => s.pending == 1)));
    online.add(false);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(gateway.batches, isEmpty);

    online.add(true);
    await expectLater(cubit.stream, emitsThrough(predicate<SyncState>((s) => s.pending == 0 && !s.syncing)));
    expect(gateway.batches, hasLength(1));

    await cubit.close();
    await online.close();
    await db.close();
  });

  group('estado', () {
    late AppDatabase db;
    late LocalRepository repo;
    final now = DateTime(2026, 3, 20, 14, 32);

    setUp(() async {
      db = memoryDatabase();
      repo = LocalRepository(db);
      await repo.saveCow(Cow(id: 'c1', tag: 'V-01', productionStatus: ProductionStatus.lactating, updatedAt: DateTime(2026)));
    });

    tearDown(() => db.close());

    test('al volver la app al frente sube lo pendiente', () async {
      final gateway = FakeGateway();
      final resumed = StreamController<void>();
      final cubit = SyncCubit(SyncService(db, gateway, sleep: (_) async {}),
          connectivity: const Stream.empty(), appResumed: resumed.stream);
      await expectLater(cubit.stream, emitsThrough(predicate<SyncState>((s) => s.pending == 1)));

      resumed.add(null);
      await expectLater(cubit.stream, emitsThrough(predicate<SyncState>((s) => s.pending == 0 && !s.syncing)));
      expect(gateway.batches, hasLength(1));
      await cubit.close();
      await resumed.close();
    });

    test('carga la última sincronización guardada y la actualiza cuando el servidor confirma', () async {
      final saved = <DateTime>[];
      final cubit = SyncCubit(
        SyncService(db, FakeGateway(), sleep: (_) async {}),
        connectivity: const Stream.empty(),
        loadLastSync: () async => DateTime(2026, 3, 19, 8),
        saveLastSync: (at) async => saved.add(at),
        clock: () => now,
      );
      await expectLater(cubit.stream, emitsThrough(predicate<SyncState>((s) => s.lastSyncAt == DateTime(2026, 3, 19, 8))));

      await cubit.syncNow();
      expect(cubit.state.lastSyncAt, now);
      expect(cubit.state.lastError, isNull);
      expect(cubit.state.message, 'Datos respaldados en el servidor.');
      expect(saved, [now]);

      // Sin nada pendiente no se contacta al servidor y la hora no cambia
      await cubit.syncNow();
      expect(saved, [now]);
      await cubit.close();
    });

    test('sin red deja el error del último intento y lo borra cuando vuelve a funcionar', () async {
      final gateway = FakeGateway(failures: 4);
      final cubit = SyncCubit(SyncService(db, gateway, sleep: (_) async {}), connectivity: const Stream.empty());
      await expectLater(cubit.stream, emitsThrough(predicate<SyncState>((s) => s.pending == 1)));

      await cubit.syncNow(silent: true);
      expect(cubit.state.lastError, contains('No hay conexión'));
      expect(cubit.state.message, isNull);
      expect(cubit.state.hasProblems, isTrue);
      expect(cubit.state.lastSyncAt, isNull);

      await cubit.syncNow();
      expect(cubit.state.lastError, isNull);
      expect(cubit.state.lastSyncAt, isNotNull);
      await cubit.close();
    });

    test('muestra lo rechazado por el servidor con su motivo', () async {
      await repo.saveRecord(DailyRecord(id: 'r1', cowId: 'c1', recordDate: DateTime(2026, 3, 20), milkL: 12, updatedAt: now));
      final gateway = FakeGateway(reject: {'r1': 'Ya existe otro registro de esa vaca para ese día.'});
      final cubit = SyncCubit(SyncService(db, gateway, sleep: (_) async {}), connectivity: const Stream.empty());
      await expectLater(cubit.stream, emitsThrough(predicate<SyncState>((s) => s.pending == 2)));

      await cubit.syncNow();
      expect(cubit.state.message, '1 cambio(s) fueron rechazados por el servidor.');
      // El rechazo puede haber llegado ya desde la base antes de escuchar el stream
      if (cubit.state.rejected.isEmpty) await cubit.stream.firstWhere((s) => s.rejected.isNotEmpty);
      expect(cubit.state.rejected.single.reason, 'Ya existe otro registro de esa vaca para ese día.');
      expect(cubit.state.hasProblems, isTrue);
      await cubit.close();
    });
  });

  test('en la sesión de demostración no hace nada', () async {
    final cubit = SyncCubit.disabled();
    await cubit.syncNow();
    expect(cubit.state.enabled, isFalse);
    await cubit.close();
  });
}
