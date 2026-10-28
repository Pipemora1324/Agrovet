import 'package:agrovet/core/theme.dart';
import 'package:agrovet/data/remote/api_client.dart';
import 'package:agrovet/data/remote/auth_api.dart';
import 'package:agrovet/data/security/secure_store.dart';
import 'package:agrovet/domain/entities.dart';
import 'package:agrovet/domain/repositories.dart';
import 'package:agrovet/domain/risk_evaluator.dart';
import 'package:agrovet/domain/session.dart';
import 'package:agrovet/presentation/auth/auth_cubit.dart';
import 'package:agrovet/presentation/auth/login_screen.dart';
import 'package:agrovet/presentation/cows/cows_screen.dart';
import 'package:agrovet/presentation/risk/risk_cubit.dart';
import 'package:agrovet/presentation/risk/risk_screen.dart';
import 'package:agrovet/presentation/sync/sync_cubit.dart';
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

class _FixedCows implements CowRepository {
  _FixedCows(this.cows);

  final List<CowSummary> cows;

  @override
  Stream<List<CowSummary>> watchCows() => Stream.value(cows);

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
