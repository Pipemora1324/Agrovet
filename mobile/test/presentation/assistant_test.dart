import 'dart:async';
import 'dart:convert';

import 'package:agrovet/core/theme.dart';
import 'package:agrovet/data/local/app_database.dart';
import 'package:agrovet/data/local/local_repository.dart';
import 'package:agrovet/data/photos/photo_capture.dart';
import 'package:agrovet/data/remote/api_client.dart';
import 'package:agrovet/data/remote/assistant_api.dart';
import 'package:agrovet/data/remote/online_status.dart';
import 'package:agrovet/data/security/secure_store.dart';
import 'package:agrovet/domain/assistant_tips.dart';
import 'package:agrovet/domain/entities.dart';
import 'package:agrovet/domain/repositories.dart';
import 'package:agrovet/presentation/assistant/assistant_cubit.dart';
import 'package:agrovet/presentation/assistant/assistant_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../data/photos_test.dart' show jpegWithLocation;
import '../helpers.dart';

class _MockAssistantApi extends Mock implements AssistantApi {}

class _MockRecords extends Mock implements RecordRepository {}

class _MockInferences extends Mock implements InferenceRepository {}

/// Conversación vacía en memoria: la pantalla no necesita la base (sus temporizadores no terminan
/// dentro del reloj falso de testWidgets).
class _EmptyChat implements AssistantRepository {
  @override
  Stream<List<AssistantMessage>> watchMessages(String cowId) => Stream.value(const []);

  @override
  Future<List<AssistantMessage>> recentMessages(String cowId, int limit) async => const [];

  @override
  Future<void> saveMessage(AssistantMessage message) async {}

  @override
  Future<void> clearMessages(String cowId) async {}
}

class _Capture implements PhotoCapture {
  @override
  Future<CaptureResult> pick(PhotoSource source) async => Captured(jpegWithLocation());
}

void main() {
  late AppDatabase db;
  late LocalRepository repo;
  late _MockAssistantApi api;
  late StreamController<bool> network;
  final now = DateTime(2026, 11, 8, 10);

  setUpAll(() {
    registerFallbackValue(const AssistantContext());
    return initializeDateFormatting('es');
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    db = memoryDatabase();
    repo = LocalRepository(db, clock: () => now);
    api = _MockAssistantApi();
    network = StreamController<bool>.broadcast();
    await repo.saveCow(Cow(id: 'c1', tag: 'V-01', productionStatus: ProductionStatus.lactating, updatedAt: now));
    await repo.saveRecord(DailyRecord(
      id: 'r1',
      cowId: 'c1',
      recordDate: dateOnly(now),
      symptoms: const Symptoms(abnormalMilk: true, udderHeat: true),
      updatedAt: now,
    ));
    await repo.saveInference(Inference(
      id: 'i1',
      cowId: 'c1',
      windowEndDate: dateOnly(now),
      symptomScore: 5,
      cause: RiskCause.symptoms,
      riskLevel: RiskLevel.red,
      modelVersion: 'x',
      updatedAt: now,
    ));
  });

  tearDown(() async {
    await network.close();
    await db.close();
  });

  var tick = 0;

  AssistantCubit cubit({bool online = true}) => AssistantCubit(
        cowId: 'c1',
        api: api,
        messages: repo,
        records: repo,
        inferences: repo,
        capture: _Capture(),
        connectivity: network.stream,
        initiallyOnline: online,
        // Cada mensaje un segundo después del anterior, para que el orden sea claro
        clock: () => now.add(Duration(seconds: tick++)),
      );

  void answer(String text) => when(() => api.ask(
        question: any(named: 'question'),
        context: any(named: 'context'),
        history: any(named: 'history'),
        photoJpeg: any(named: 'photoJpeg'),
      )).thenAnswer((_) async => text);

  test('guarda la pregunta y la respuesta y envía el semáforo y los síntomas de hoy', () async {
    answer('Revise la ubre y llame al veterinario si ve sangre.');
    final chat = cubit();
    expect(await chat.send('¿Qué hago?'), isTrue);

    final messages = await repo.watchMessages('c1').first;
    expect(messages.map((m) => (m.fromUser, m.text)), [
      (true, '¿Qué hago?'),
      (false, 'Revise la ubre y llame al veterinario si ve sangre.'),
    ]);
    final captured = verify(() => api.ask(
          question: '¿Qué hago?',
          context: captureAny(named: 'context'),
          history: any(named: 'history'),
          photoJpeg: null,
        )).captured.single as AssistantContext;
    expect(captured.riskLevel, RiskLevel.red);
    expect(captured.cause, RiskCause.symptoms);
    expect(captured.symptoms, ['Grumos o sangre en la leche', 'Ubre caliente']);
    expect(captured.toJson().keys, isNot(contains('email')));
    await chat.close();
  });

  test('envía como máximo los 6 mensajes anteriores', () async {
    answer('ok');
    final chat = cubit();
    for (var i = 0; i < 5; i++) {
      await chat.send('pregunta $i');
    }
    final history = verify(() => api.ask(
          question: 'pregunta 4',
          context: any(named: 'context'),
          history: captureAny(named: 'history'),
          photoJpeg: any(named: 'photoJpeg'),
        )).captured.single as List<AssistantMessage>;
    expect(history, hasLength(AssistantCubit.historyTurns));
    expect(history.last.text, 'ok');
    await chat.close();
  });

  test('sin internet no consulta y lo explica; al volver la red, se puede', () async {
    answer('ok');
    final chat = cubit(online: false);
    expect(await chat.send('Hola'), isFalse);
    expect(chat.state.error, contains('Sin internet'));
    verifyNever(() => api.ask(question: any(named: 'question')));
    expect(await repo.watchMessages('c1').first, isEmpty);

    network.add(true);
    await Future<void>.delayed(Duration.zero);
    expect(await chat.send('Hola'), isTrue);
    await chat.close();
  });

  test('la foto sale sin ubicación y, si falla el envío, no se pierde', () async {
    when(() => api.ask(
          question: any(named: 'question'),
          context: any(named: 'context'),
          history: any(named: 'history'),
          photoJpeg: any(named: 'photoJpeg'),
        )).thenThrow(const ApiException('El asistente no está disponible en este momento.', statusCode: 503));
    final chat = cubit();
    await chat.attachPhoto(PhotoSource.camera);
    expect(latin1.decode(chat.state.photo!), isNot(contains('GPS')));

    await chat.send('¿Cómo ve la ubre?');
    expect(chat.state.error, contains('no está disponible'));
    expect(chat.state.photo, isNotNull);
    expect((await repo.watchMessages('c1').first).single.withPhoto, isTrue);
    await chat.close();
  });

  group('pantalla', () {
    Widget app(OnlineStatus status) => MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ApiClient>.value(value: ApiClient(baseUrl: 'http://localhost:1', store: SecureStore())),
            RepositoryProvider<AssistantRepository>.value(value: _EmptyChat()),
            RepositoryProvider<RecordRepository>.value(value: _MockRecords()),
            RepositoryProvider<InferenceRepository>.value(value: _MockInferences()),
            RepositoryProvider<PhotoCapture>.value(value: _Capture()),
            RepositoryProvider<OnlineStatus>.value(value: status),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('es'),
            supportedLocales: const [Locale('es')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: AssistantScreen(
              cow: Cow(id: 'c1', tag: 'V-01', name: 'Lucero', productionStatus: ProductionStatus.lactating, updatedAt: now),
            ),
          ),
        );

    testWidgets('el aviso fijo siempre está y sin internet hay banner y consejos', (tester) async {
      final status = OnlineStatus(network.stream, initial: false);
      addTearDown(status.dispose);
      await tester.pumpWidget(app(status));
      await tester.pumpAndSettle();

      expect(find.text(AssistantTips.notice), findsOneWidget);
      expect(find.textContaining('Sin internet'), findsOneWidget);
      expect(find.text('Higiene del ordeño'), findsOneWidget);
      expect(find.textContaining('Separe a la vaca'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      network.add(true);
      await tester.pumpAndSettle();
      expect(find.textContaining('Sin internet'), findsNothing);
      expect(find.text(AssistantTips.notice), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    });
  });
}
