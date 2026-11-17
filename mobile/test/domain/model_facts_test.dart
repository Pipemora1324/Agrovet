// "Acerca del modelo" no puede inventar cifras: cada número de sus textos debe estar en ml/README.md.
import 'dart:io';

import 'package:agrovet/core/theme.dart';
import 'package:agrovet/domain/model_facts.dart';
import 'package:agrovet/presentation/about/about_model_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final readme = File('../ml/README.md').readAsStringSync();
  final allText = [ModelFacts.disclaimer, for (final s in ModelFacts.sections) ...s.allText];

  test('cada número de la pantalla aparece tal cual en ml/README.md', () {
    // Números sueltos (no los de nombres como MobileNetV2), con coma decimal
    final number = RegExp(r'(?<![\w,])\d+(?:,\d+)?(?![\w])');
    final numbers = {for (final text in allText) ...number.allMatches(text).map((m) => m.group(0)!)};
    expect(numbers, isNotEmpty);
    bool inReadme(String n) => RegExp(r'(?<![\d,])' + RegExp.escape(n) + r'(?![\d])').hasMatch(readme);
    // La comprobación distingue: 0,49 está, 0,4 solo como parte de otras cifras no cuenta, y una
    // cifra inventada no está
    expect(inReadme('0,49'), isTrue);
    expect(inReadme('0,4'), isFalse);
    expect(inReadme('0,777'), isFalse);
    final missing = [
      for (final n in numbers)
        if (!inReadme(n)) n,
    ];
    expect(missing, isEmpty, reason: 'Cifras que no están en ml/README.md: $missing');
  });

  test('dice lo esencial: sintético, cifras de prueba, líneas base y CNN experimentales', () {
    final joined = allText.join('\n');
    expect(ModelFacts.disclaimer, 'No es diagnóstico, no validado con datos reales.');
    expect(joined, contains('14 días'));
    expect(joined, contains('SINTÉTICOS'));
    expect(joined, contains('0,49'));
    expect(joined, contains('0,89'));
    expect(joined, contains('Umbral de temperatura'));
    expect(joined, contains('Regresión logística'));
    expect(joined, contains('Random forest'));
    expect(joined, contains('Leche (experimental)'));
    expect(joined, contains('Ubre (experimental)'));
    // El README también trae estas mismas cifras del LSTM y su aviso de datos sintéticos
    expect(readme, contains('**0,49 (0,40–0,57)**'));
    expect(readme, contains('**0,89 (0,87–0,91)**'));
    expect(readme, contains('no validan la hipótesis F1 ≥ 0,80'));
  });

  testWidgets('la pantalla muestra el aviso arriba y abajo y todas las secciones', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const AboutModelScreen(),
    ));
    await tester.pumpAndSettle();
    expect(find.text(ModelFacts.disclaimer), findsNWidgets(2));
    for (final section in ModelFacts.sections) {
      await tester.scrollUntilVisible(find.text(section.title), 200);
      expect(find.text(section.title), findsOneWidget);
    }
  });
}
