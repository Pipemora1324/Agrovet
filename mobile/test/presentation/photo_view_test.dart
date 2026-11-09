import 'dart:io';

import 'package:agrovet/core/theme.dart';
import 'package:agrovet/data/photos/photo_store.dart';
import 'package:agrovet/domain/entities.dart';
import 'package:agrovet/domain/repositories.dart';
import 'package:agrovet/presentation/photos/photo_view_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPhotoRepository extends Mock implements PhotoRepository {}

void main() {
  final photo = CowPhoto(
    id: 'p1',
    cowId: 'c1',
    takenOn: DateTime(2026, 11, 9),
    fileName: 'p1.jpg',
    sizeBytes: 10,
    createdAt: DateTime(2026, 11, 9),
  );

  setUpAll(() => registerFallbackValue(photo));

  Future<_MockPhotoRepository> open(WidgetTester tester) async {
    final repository = _MockPhotoRepository();
    when(() => repository.savePhoto(any())).thenAnswer((_) async {});
    await tester.pumpWidget(MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => PhotoStore(Directory.systemTemp)),
        RepositoryProvider<PhotoRepository>.value(value: repository),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: PhotoViewScreen(photo: photo)),
    ));
    await tester.pump();
    return repository;
  }

  testWidgets('los datos para investigación son opcionales y empiezan plegados', (tester) async {
    await open(tester);
    expect(find.text('Para investigación (opcional)'), findsOneWidget);
    expect(find.text('Permitir usar esta foto para investigación'), findsNothing);
  });

  testWidgets('con letra al 130 % en pantalla pequeña las opciones no parten palabras y miden 56 dp', (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester);
    await tester.tap(find.text('Para investigación (opcional)'));
    await tester.pumpAndSettle();

    final buttons = tester.widgetList<SegmentedButton<Object?>>(find.byWidgetPredicate((w) => w is SegmentedButton));
    expect(buttons, isNotEmpty);
    // "Pendiente" no cabe en un tercio del ancho: ese selector pasa a vertical
    expect(buttons.any((b) => b.direction == Axis.vertical), isTrue);
    for (final segment in find.byWidgetPredicate((w) => w is TextButton).evaluate()) {
      expect(tester.getSize(find.byWidget(segment.widget)).height, greaterThanOrEqualTo(56));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('al desplegar, el permiso empieza apagado y se guarda lo elegido', (tester) async {
    final repository = await open(tester);
    await tester.tap(find.text('Para investigación (opcional)'));
    await tester.pumpAndSettle();

    final consent = find.byType(SwitchListTile);
    await tester.ensureVisible(consent);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(consent).value, isFalse);
    await tester.tap(consent);
    await tester.pump();
    await tester.ensureVisible(find.text('Guardar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    final saved = verify(() => repository.savePhoto(captureAny())).captured.single as CowPhoto;
    expect(saved.researchConsent, isTrue);
    expect(saved.vetConfirmed, isNull);
    expect(find.text('Datos de la foto guardados.'), findsOneWidget);
  });
}
