import 'dart:async';

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

  test('en la sesión de demostración no hace nada', () async {
    final cubit = SyncCubit.disabled();
    await cubit.syncNow();
    expect(cubit.state.enabled, isFalse);
    await cubit.close();
  });
}
