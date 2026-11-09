import 'package:agrovet/core/theme.dart';
import 'package:agrovet/data/remote/api_client.dart';
import 'package:agrovet/data/remote/auth_api.dart';
import 'package:agrovet/data/security/secure_store.dart';
import 'package:agrovet/domain/entities.dart';
import 'package:agrovet/domain/repositories.dart';
import 'package:agrovet/domain/session.dart';
import 'package:agrovet/presentation/auth/auth_cubit.dart';
import 'package:agrovet/presentation/auth/login_screen.dart';
import 'package:agrovet/presentation/cows/cow_detail_screen.dart';
import 'package:agrovet/presentation/cows/cows_screen.dart';
import 'package:agrovet/presentation/sync/sync_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Las pantallas principales en celular pequeño, celular grande, tableta vertical y horizontal, con
/// la letra al 130 %. Un desbordamiento hace fallar la prueba.
void main() {
  setUpAll(() => initializeDateFormatting('es'));

  const sizes = {
    'celular 360x640': Size(360, 640),
    'celular 411x891': Size(411, 891),
    'tableta 800x1280': Size(800, 1280),
    'tableta horizontal 1280x800': Size(1280, 800),
  };

  final today = dateOnly(DateTime.now());
  final repo = _Herd(today);

  Future<void> pumpScreen(WidgetTester tester, Size size, Widget screen) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final store = SecureStore();
    final auth = AuthCubit(store: store, api: AuthApi(ApiClient(baseUrl: 'http://localhost:1', store: store)))
      ..emit(const Unauthenticated());
    await tester.pumpWidget(MultiRepositoryProvider(
      providers: [
        RepositoryProvider<Session>.value(value: const Session(userId: 'u', name: 'Ana', email: 'ana@correo.co')),
        RepositoryProvider<CowRepository>.value(value: repo),
        RepositoryProvider<RecordRepository>.value(value: repo),
        RepositoryProvider<InferenceRepository>.value(value: repo),
        RepositoryProvider<AlertRepository>.value(value: repo),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: auth),
          BlocProvider(create: (_) => SyncCubit.disabled()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: screen,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final MapEntry(key: name, value: size) in sizes.entries) {
    final tablet = size.width >= 700;

    testWidgets('ingreso sin desbordes en $name', (tester) async {
      await pumpScreen(tester, size, const LoginScreen());
      expect(find.text('AgroVet'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // El formulario no pasa del ancho máximo en tableta
      expect(tester.getSize(find.byType(Card).first).width, lessThanOrEqualTo(520));
    });

    testWidgets('lista de vacas en $name', (tester) async {
      await pumpScreen(tester, size, const CowsScreen());
      expect(tester.takeException(), isNull);
      final first = tester.getTopLeft(find.text('Canela'));
      final second = tester.getTopLeft(find.text('Paloma'));
      if (tablet) {
        expect(second.dy, first.dy, reason: 'dos columnas');
        expect(second.dx, greaterThan(first.dx));
        // Contenido centrado con ancho máximo
        expect(tester.getSize(find.byType(ListView)).width, size.width);
        expect(tester.getTopLeft(find.text('Riesgo alto')).dx, greaterThanOrEqualTo((size.width - 720) / 2));
      } else {
        expect(second.dy, greaterThan(first.dy), reason: 'una columna');
        expect(second.dx, first.dx);
      }
    });

    testWidgets('ficha de la vaca en $name', (tester) async {
      await pumpScreen(tester, size, const CowDetailScreen(cowId: 'c1'));
      expect(tester.takeException(), isNull);
      expect(find.text('Por qué la app lo cree'), findsOneWidget);
      final reasons = tester.getTopLeft(find.text('Por qué la app lo cree'));
      final chart = tester.getTopLeft(find.text('Temperatura, 14 días'));
      if (tablet) {
        // Dos paneles: semáforo y razones a la izquierda, gráfica a la derecha
        expect(chart.dx, greaterThan(reasons.dx + 200));
      } else {
        expect(chart.dx, lessThan(reasons.dx + 50));
      }
    });
  }
}

/// Dos vacas: Canela con riesgo alto y 14 días de registros, Paloma sana.
class _Herd implements CowRepository, RecordRepository, InferenceRepository, AlertRepository {
  _Herd(this.today);

  final DateTime today;

  late final canela = Cow(
    id: 'c1',
    tag: 'NAR-0001',
    name: 'Canela',
    breed: 'Normando',
    birthDate: DateTime(2020, 5, 1),
    calvings: 3,
    productionStatus: ProductionStatus.lactating,
    updatedAt: today,
  );
  late final paloma = Cow(id: 'c2', tag: 'NAR-0002', name: 'Paloma', productionStatus: ProductionStatus.dry, updatedAt: today);

  @override
  Stream<List<CowSummary>> watchCows() => Stream.value([
        CowSummary(cow: canela, lastRisk: RiskLevel.red, lastRecordDate: today),
        CowSummary(cow: paloma, lastRisk: RiskLevel.green, lastRecordDate: today.subtract(const Duration(days: 2))),
      ]);

  @override
  Stream<Cow?> watchCow(String id) => Stream.value(id == 'c1' ? canela : paloma);

  @override
  Future<List<DailyRecord>> recordsBetween(String cowId, DateTime from, DateTime to) async => [
        for (var i = 0; i < 14; i++)
          DailyRecord(
            id: 'r$i',
            cowId: cowId,
            recordDate: from.add(Duration(days: i)),
            temperatureC: 38.4 + (i > 10 ? 1.3 : 0.1 * (i % 3)),
            milkL: 14.0 - (i > 10 ? 3 : 0),
            feedKg: 11.0,
            symptoms: i == 13 ? const Symptoms(udderHeat: true, abnormalMilk: true) : const Symptoms(),
            updatedAt: today,
          ),
      ];

  @override
  Stream<Inference?> watchLatest(String cowId) => Stream.value(Inference(
        id: 'i1',
        cowId: cowId,
        windowEndDate: today,
        probability: 0.91,
        symptomScore: 5,
        cause: RiskCause.both,
        riskLevel: RiskLevel.red,
        modelVersion: 'prueba',
        updatedAt: today,
      ));

  @override
  Stream<List<CowAlert>> watchPendingAlerts(String cowId) =>
      Stream.value([CowAlert(id: 'a1', cowId: cowId, riskLevel: RiskLevel.red, createdAt: today)]);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
