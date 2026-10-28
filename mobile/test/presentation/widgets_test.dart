import 'dart:async';

import 'package:agrovet/core/theme.dart';
import 'package:agrovet/data/remote/api_client.dart';
import 'package:agrovet/data/remote/auth_api.dart';
import 'package:agrovet/data/security/secure_store.dart';
import 'package:agrovet/data/sync/sync_service.dart';
import 'package:agrovet/domain/entities.dart';
import 'package:agrovet/domain/repositories.dart';
import 'package:agrovet/domain/risk_evaluator.dart';
import 'package:agrovet/domain/session.dart';
import 'package:agrovet/presentation/auth/auth_cubit.dart';
import 'package:agrovet/presentation/auth/login_screen.dart';
import 'package:agrovet/presentation/cows/cow_detail_screen.dart';
import 'package:agrovet/presentation/cows/cows_screen.dart';
import 'package:agrovet/presentation/risk/risk_cubit.dart';
import 'package:agrovet/presentation/risk/risk_screen.dart';
import 'package:agrovet/presentation/sync/sync_cubit.dart';
import 'package:agrovet/presentation/sync/sync_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers.dart';

Widget app(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: child,
    );

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  AuthCubit authCubit({bool allowDemo = true}) {
    final store = SecureStore();
    return AuthCubit(
      store: store,
      api: AuthApi(ApiClient(baseUrl: 'http://localhost:1', store: store)),
      allowDemo: allowDemo,
    );
  }

  testWidgets('el login valida los campos y ofrece la demostración solo si está permitida', (tester) async {
    final cubit = authCubit()..emit(const Unauthenticated());
    await tester.pumpWidget(BlocProvider.value(value: cubit, child: app(const LoginScreen())));
    await tester.pumpAndSettle();

    expect(find.text('AgroVet'), findsOneWidget);
    expect(find.text('Ver con datos de demostración'), findsOneWidget);
    await tester.tap(find.text('Ingresar'));
    await tester.pump();
    expect(find.text('Escriba su correo'), findsOneWidget);
    expect(find.text('La contraseña debe tener al menos 8 caracteres'), findsOneWidget);

    final noDemo = authCubit(allowDemo: false)..emit(const Unauthenticated());
    await tester.pumpWidget(BlocProvider.value(value: noDemo, child: app(const LoginScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Ver con datos de demostración'), findsNothing);
  });

  group('lista de vacas', () {
    final repo = _FixedCows([
      for (var i = 1; i <= 4; i++)
        CowSummary(
          cow: Cow(
            id: 'c$i',
            tag: 'DEMO-0$i',
            name: 'Vaca $i',
            productionStatus: ProductionStatus.lactating,
            updatedAt: DateTime(2026, 3, 20),
          ),
          lastRisk: i == 2 ? RiskLevel.red : null,
        ),
    ]);

    Future<void> pumpCows(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MultiRepositoryProvider(
        providers: [
          RepositoryProvider<Session>.value(
              value: const Session(userId: 'demo', name: 'Demo', email: 'd@x.co', isDemo: true)),
          RepositoryProvider<CowRepository>.value(value: repo),
          RepositoryProvider.value(value: authCubit()),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: authCubit()),
            BlocProvider(create: (_) => SyncCubit.disabled()),
          ],
          child: app(const CowsScreen()),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('en celular muestra una columna y el rótulo de demostración', (tester) async {
      await pumpCows(tester, const Size(400, 800));
      expect(find.text('Datos de demostración'), findsOneWidget);
      expect(find.text('Vaca 1'), findsOneWidget);
      final first = tester.getTopLeft(find.text('Vaca 1'));
      final second = tester.getTopLeft(find.text('Vaca 2'));
      expect(second.dy, greaterThan(first.dy));
      expect(second.dx, first.dx);
    });

    testWidgets('en tableta muestra las vacas en dos columnas', (tester) async {
      await pumpCows(tester, const Size(1000, 800));
      final first = tester.getTopLeft(find.text('Vaca 1'));
      final second = tester.getTopLeft(find.text('Vaca 2'));
      expect(second.dy, first.dy);
      expect(second.dx, greaterThan(first.dx));
    });
  });

  testWidgets('el resultado muestra el semáforo, la recomendación y el aviso fijo', (tester) async {
    final cow = Cow(id: 'c1', tag: 'V-01', name: 'Lucero', productionStatus: ProductionStatus.lactating, updatedAt: DateTime(2026));
    final cubit = _FixedRiskCubit(RiskState(
      evaluating: false,
      outcome: RiskResult(probability: 0.9, level: RiskLevel.red, windowEnd: DateTime.now()),
      todaySymptoms: const Symptoms(),
    ));
    await tester.pumpWidget(BlocProvider<RiskCubit>.value(value: cubit, child: app(RiskView(cow: cow))));
    await tester.pumpAndSettle();
    expect(find.text('Alto riesgo'), findsOneWidget);
    expect(find.text('Consulte al veterinario'), findsOneWidget);
    expect(find.text('Esta herramienta apoya, no reemplaza al veterinario.'), findsOneWidget);
    expect(find.textContaining('Probabilidad estimada: 90 %'), findsOneWidget);
  });

  testWidgets('la ficha muestra la alerta sin atender y permite marcarla como atendida', (tester) async {
    final repo = _CowWithAlerts(
      Cow(id: 'c1', tag: 'V-01', name: 'Lucero', productionStatus: ProductionStatus.lactating, updatedAt: DateTime(2026)),
      [CowAlert(id: 'al1', cowId: 'c1', riskLevel: RiskLevel.red, createdAt: DateTime.now())],
    );
    addTearDown(repo.dispose);
    await tester.pumpWidget(MultiRepositoryProvider(
      providers: [
        RepositoryProvider<CowRepository>.value(value: repo),
        RepositoryProvider<InferenceRepository>.value(value: repo),
        RepositoryProvider<AlertRepository>.value(value: repo),
      ],
      child: BlocProvider(create: (_) => SyncCubit.disabled(), child: app(const CowDetailScreen(cowId: 'c1'))),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Alerta sin atender'), findsOneWidget);
    expect(find.text('Alto riesgo'), findsOneWidget);
    await tester.tap(find.text('Marcar como atendida'));
    await tester.pumpAndSettle();

    expect(repo.attended, ['al1']);
    expect(find.text('Alerta marcada como atendida.'), findsOneWidget);
    expect(find.text('Alerta sin atender'), findsNothing);
    expect(find.text('Registro de hoy'), findsOneWidget);
  });

  testWidgets('el respaldo muestra pendientes, última sincronización, errores y el botón', (tester) async {
    final cubit = _FixedSyncCubit(SyncState(
      pending: 3,
      lastSyncAt: DateTime.now().copyWith(hour: 14, minute: 32),
      lastError: 'No hay conexión con el servidor.',
      rejected: const [
        SyncIssue(kind: 'Registro', label: 'V-01 · 2026-03-20', reason: 'Ya existe otro registro de esa vaca para ese día.'),
      ],
    ));
    await tester.pumpWidget(BlocProvider<SyncCubit>.value(value: cubit, child: app(const SyncScreen())));
    await tester.pumpAndSettle();

    expect(find.text('Hay un problema'), findsOneWidget);
    expect(find.text('Pendientes: '), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Hoy, 14:32'), findsOneWidget);
    expect(find.textContaining('Último intento: No hay conexión con el servidor.'), findsOneWidget);
    expect(find.text('Registro · V-01 · 2026-03-20'), findsOneWidget);
    expect(find.text('Ya existe otro registro de esa vaca para ese día.'), findsOneWidget);

    await tester.tap(find.text('Sincronizar ahora'));
    expect(cubit.requested, 1);

    cubit.show(const SyncState());
    await tester.pumpAndSettle();
    expect(find.text('Todo respaldado'), findsOneWidget);
    expect(find.text('Todavía no'), findsOneWidget);
  });

  testWidgets('con pocos datos explica cuántos días faltan', (tester) async {
    final cow = Cow(id: 'c1', tag: 'V-01', productionStatus: ProductionStatus.lactating, updatedAt: DateTime(2026));
    final cubit = _FixedRiskCubit(const RiskState(
      evaluating: false,
      outcome: InsufficientData(recordedDays: 6, requiredDays: 10, windowDays: 14),
    ));
    await tester.pumpWidget(BlocProvider<RiskCubit>.value(value: cubit, child: app(RiskView(cow: cow))));
    await tester.pumpAndSettle();
    expect(find.text('Faltan registros'), findsOneWidget);
    expect(find.textContaining('Hay 6 de los últimos 14 días'), findsOneWidget);
    expect(find.text('Esta herramienta apoya, no reemplaza al veterinario.'), findsOneWidget);
  });
}

class _FixedRiskCubit extends RiskCubit {
  _FixedRiskCubit(RiskState initial)
      : super(
          cowId: 'c1',
          records: _NoRecords(),
          inferences: _NoInferences(),
          evaluator: RiskEvaluator(FakePredictor(0)),
        ) {
    emit(initial);
  }

  @override
  Future<void> evaluate() async {}
}

class _FixedSyncCubit extends SyncCubit {
  _FixedSyncCubit(SyncState initial) : super.disabled() {
    emit(initial);
  }

  int requested = 0;

  void show(SyncState state) => emit(state);

  @override
  Future<void> syncNow({bool silent = false}) async => requested++;
}

class _FixedCows implements CowRepository {
  _FixedCows(this.cows);

  final List<CowSummary> cows;

  @override
  Stream<List<CowSummary>> watchCows() => Stream.value(cows);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Una vaca con alertas en memoria; marcar una la quita de la lista, como la base real.
class _CowWithAlerts implements CowRepository, InferenceRepository, AlertRepository {
  _CowWithAlerts(this.cow, List<CowAlert> alerts) : _alerts = [...alerts];

  final Cow cow;
  final List<CowAlert> _alerts;
  final _changes = StreamController<List<CowAlert>>.broadcast(sync: true);
  final List<String> attended = [];

  @override
  Stream<Cow?> watchCow(String id) => Stream.value(cow);

  @override
  Stream<Inference?> watchLatest(String cowId) => Stream.value(null);

  @override
  Stream<List<CowAlert>> watchPendingAlerts(String cowId) async* {
    yield List.of(_alerts);
    yield* _changes.stream;
  }

  @override
  Future<void> markAlertAttended(String alertId) async {
    attended.add(alertId);
    _alerts.removeWhere((a) => a.id == alertId);
    _changes.add(List.of(_alerts));
  }

  Future<void> dispose() => _changes.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoRecords implements RecordRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoInferences implements InferenceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
