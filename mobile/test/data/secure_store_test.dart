import 'package:agrovet/data/security/secure_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('la última sincronización se guarda por usuario', () async {
    final store = SecureStore();
    expect(await store.lastSyncFor('u1'), isNull);

    final at = DateTime(2026, 3, 20, 14, 32);
    await store.saveLastSync('u1', at);

    expect(await store.lastSyncFor('u1'), at);
    expect(await store.lastSyncFor('u2'), isNull);
  });
}
