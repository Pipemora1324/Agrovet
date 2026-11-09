import 'package:agrovet/core/theme.dart';
import 'package:agrovet/domain/entities.dart';
import 'package:agrovet/domain/repositories.dart';
import 'package:agrovet/domain/risk_advice.dart';
import 'package:agrovet/presentation/records/daily_record_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  final cow = Cow(id: 'c1', tag: 'V-01', name: 'Lucero', productionStatus: ProductionStatus.lactating, updatedAt: DateTime(2026));

  /// Abre el registro desde una pantalla anterior, para poder volver.
  Future<_Records> open(WidgetTester tester, {Size size = const Size(411, 891), double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final records = _Records();
    await tester.pumpWidget(RepositoryProvider<RecordRepository>.value(
      value: records,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DailyRecordScreen(cow: cow))),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return records;
  }

  Future<void> choose(WidgetTester tester, String option) async {
    await tester.ensureVisible(find.text(option));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option));
    await tester.pumpAndSettle();
  }

  testWidgets('una pregunta por pantalla, pasa sola y termina con los valores estimados', (tester) async {
    final records = await open(tester);
    expect(find.text('Pregunta 1 de 4'), findsOneWidget);
    expect(find.text('¿Cómo comió hoy?'), findsOneWidget);
    expect(find.text('No sé'), findsOneWidget);
    expect(find.text(RiskAdvice.disclaimer), findsOneWidget);

    await choose(tester, 'Menos de lo normal');
    expect(find.text('Pregunta 2 de 4'), findsOneWidget);
    expect(find.text('¿Cuánta leche dio?'), findsOneWidget);
    await choose(tester, 'Un poco menos');
    expect(find.text('Al tocarla, ¿cómo siente el cuerpo?'), findsOneWidget);
    await choose(tester, 'Caliente');
    expect(find.text('¿Cómo ves la ubre y la leche?'), findsOneWidget);
    await choose(tester, 'Ubre caliente, dura o hinchada');

    // Pantalla final: sin historial se usan los valores de referencia y se dice
    expect(find.text('¡Listo!'), findsOneWidget);
    expect(find.text('Temperatura: 40,1 °C'), findsOneWidget);
    expect(find.text('Leche: 11,7 L'), findsOneWidget);
    expect(find.text('Alimento: 9,4 kg'), findsOneWidget);
    expect(find.text('estimado'), findsNWidgets(3));
    expect(find.textContaining('valores de referencia'), findsOneWidget);
    expect(find.text(RiskAdvice.disclaimer), findsOneWidget);

    // Con termómetro, la medida exacta reemplaza a la estimada
    await choose(tester, 'Tengo termómetro o litros exactos');
    await tester.enterText(find.widgetWithText(TextFormField, 'Temperatura (opcional)'), '38,9');
    await tester.pumpAndSettle();
    expect(find.text('Temperatura: 38,9 °C'), findsOneWidget);
    expect(find.text('medido'), findsOneWidget);

    await choose(tester, 'Guardar registro');
    final saved = records.saved.single;
    expect(saved.temperatureC, 38.9);
    expect(saved.temperatureSource, ValueSource.measured);
    expect(saved.milkSource, ValueSource.estimated);
    expect(saved.symptoms.udderSwelling, isTrue);
    expect(saved.symptoms.ateNormally, isFalse);
    expect(find.text('abrir'), findsOneWidget, reason: 'vuelve a la pantalla anterior');
  });

  testWidgets('atrás, empezar de nuevo y saltar por hoy', (tester) async {
    final records = await open(tester);
    await choose(tester, 'Normal');
    await choose(tester, 'Atrás');
    expect(find.text('Pregunta 1 de 4'), findsOneWidget);
    await choose(tester, 'Normal');
    await choose(tester, 'Igual');
    await choose(tester, 'Empezar de nuevo');
    expect(find.text('Pregunta 1 de 4'), findsOneWidget);
    await choose(tester, 'Saltar por hoy');
    expect(find.text('abrir'), findsOneWidget);
    expect(records.saved, isEmpty);
  });

  const sizes = {
    'celular 360x640': Size(360, 640),
    'celular 411x891': Size(411, 891),
    'tableta 800x1280': Size(800, 1280),
    'tableta horizontal 1280x800': Size(1280, 800),
  };
  for (final MapEntry(key: name, value: size) in sizes.entries) {
    testWidgets('preguntas y pantalla final sin desbordes en $name con letra al 130 %', (tester) async {
      await open(tester, size: size, textScale: 1.3);
      expect(tester.takeException(), isNull);
      await choose(tester, 'No sé');
      await choose(tester, 'No sé');
      await choose(tester, 'No sé');
      await choose(tester, 'No sé');
      expect(find.text('¡Listo!'), findsOneWidget);
      await choose(tester, 'Tengo termómetro o litros exactos');
      expect(tester.takeException(), isNull);
    });
  }
}

class _Records implements RecordRepository {
  final saved = <DailyRecord>[];

  @override
  Future<List<DailyRecord>> recordsBetween(String cowId, DateTime from, DateTime to) async => const [];

  @override
  Future<void> saveRecord(DailyRecord record) async => saved.add(record);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
