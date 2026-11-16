import 'dart:io';

import 'package:agrovet/core/config.dart';
import 'package:agrovet/data/remote/api_client.dart';
import 'package:agrovet/data/security/secure_store.dart';
import 'package:agrovet/data/sync/background_sync.dart';
import 'package:agrovet/domain/session.dart';
import 'package:agrovet/presentation/session_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const _demo = Session(userId: 'demo', name: 'Demo', email: 'demo@agrovet.co', isDemo: true);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('una sesión de demostración se abre sin servidor y carga las 6 vacas de ejemplo', (tester) async {
    final db = memoryDatabase();
    final photos = await tester.runAsync(() => Directory.systemTemp.createTemp('agrovet_demo'));
    final store = SecureStore();

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<SecureStore>.value(value: store),
            RepositoryProvider<ApiClient>.value(value: ApiClient(baseUrl: 'http://localhost:1', store: store)),
          ],
          child: MaterialApp(
            home: SessionScope(
              session: _demo,
              predictor: Future.value(FakePredictor(0.1)),
              openDatabase: (_) async => db,
              photosRoot: () async => photos!,
              connectivity: const Stream<bool>.empty(),
              child: const Text('sesión lista'),
            ),
          ),
        ),
      );
      for (var i = 0; i < 100 && find.text('sesión lista').evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });

    expect(find.text('sesión lista'), findsOneWidget);
    // La demostración existe en las pruebas porque corren en debug
    expect(AppConfig.demoAvailable, isTrue);
    final cows = await tester.runAsync(() => db.select(db.cows).get());
    expect(cows, hasLength(6));
    expect(cows!.map((c) => c.tag), everyElement(startsWith('DEMO')));

    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await photos!.delete(recursive: true);
    });
  });

  test('sin una dirección del servidor la sincronización en segundo plano no intenta subir nada', () async {
    await SecureStore().saveSession(
      const Session(userId: 'u1', name: 'Ana', email: 'ana@correo.co', accessToken: 'a', refreshToken: 'r'),
    );
    // Las pruebas se compilan sin API_BASE_URL: no hay a dónde subir y se da por terminado
    expect(AppConfig.problem, isNotNull);
    expect(await runBackgroundSync(), isTrue);
  });
}
