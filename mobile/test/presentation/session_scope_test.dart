import 'dart:io';

import 'package:agrovet/core/config.dart';
import 'package:agrovet/data/local/app_database.dart';
import 'package:agrovet/data/local/database_opener.dart';
import 'package:agrovet/data/local/local_repository.dart';
import 'package:agrovet/data/remote/api_client.dart';
import 'package:agrovet/data/security/secure_store.dart';
import 'package:agrovet/data/sync/background_sync.dart';
import 'package:agrovet/domain/entities.dart';
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

  testWidgets('lo que se agrega en la demostración sigue ahí al cerrar y volver a abrir la app', (tester) async {
    // Base cifrada en disco, como en el celular: se abre, se cierra y se vuelve a abrir el mismo archivo
    final dir = (await tester.runAsync(() => Directory.systemTemp.createTemp('agrovet_demo_db')))!;
    final file = File('${dir.path}/agrovet_demo.db');
    final store = SecureStore();
    final key = (await tester.runAsync(() => store.databaseKeyFor(_demo.userId)))!;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    Future<AppDatabase> openApp() async {
      late AppDatabase db;
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
                openDatabase: (_) async => db = AppDatabase(DatabaseOpener.openFile(file, key)),
                photosRoot: () async => dir,
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
      return db;
    }

    Future<void> closeApp() => tester.runAsync(() async {
          await tester.pumpWidget(const SizedBox());
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });

    final first = await openApp();
    await tester.runAsync(() async {
      final repo = LocalRepository(first, isDemo: true);
      await repo.saveCow(Cow(
        id: 'nueva', tag: 'F-100', name: 'Nueva', productionStatus: ProductionStatus.lactating, updatedAt: today));
      await repo.saveRecord(DailyRecord(
        id: 'nueva-hoy', cowId: 'nueva', recordDate: today, temperatureC: 39.4, milkL: 11.5, feedKg: 9,
        symptoms: const Symptoms(), updatedAt: today));
    });
    await closeApp();

    final second = await openApp();
    final cows = (await tester.runAsync(() => second.select(second.cows).get()))!;
    // Las 6 de ejemplo no se vuelven a sembrar y la vaca nueva sigue ahí, con su registro
    expect(cows, hasLength(7));
    expect(cows.map((c) => c.tag), contains('F-100'));
    final record = await tester.runAsync(() => LocalRepository(second, isDemo: true).recordFor('nueva', today));
    expect(record?.temperatureC, 39.4);
    expect(record?.milkL, 11.5);
    await closeApp();
    await tester.runAsync(() => dir.delete(recursive: true));
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
