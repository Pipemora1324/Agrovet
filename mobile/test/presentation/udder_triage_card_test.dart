import 'dart:io';

import 'package:agrovet/data/photos/photo_store.dart';
import 'package:agrovet/domain/entities.dart';
import 'package:agrovet/domain/repositories.dart';
import 'package:agrovet/domain/udder_triage.dart';
import 'package:agrovet/presentation/photos/photo_view_screen.dart';
import 'package:agrovet/presentation/photos/udder_triage_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPhotoRepository extends Mock implements PhotoRepository {}

void main() {
  testWidgets('la lectura siempre dice que es orientativa y no es diagnóstico', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: UdderTriageCard(
          photo: File('no_importa.jpg'),
          estimator: (_) async => const UdderTriageResult(0.81, 0.5),
        ),
      ),
    ));
    await tester.pump();
    expect(find.textContaining('orientativo, no es diagnóstico'), findsOneWidget);
    expect(find.text('La foto se parece a ubres con signos de mastitis'), findsOneWidget);
  });

  testWidgets('si el análisis falla lo dice sin mostrar un resultado', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: UdderTriageCard(photo: File('x.jpg'), estimator: (_) async => throw StateError('sin modelo')),
      ),
    ));
    await tester.pump();
    expect(find.text('No se pudo analizar la foto.'), findsOneWidget);
    expect(find.textContaining('no es diagnóstico'), findsOneWidget);
  });

  testWidgets('con la compilación por defecto la ficha de la foto no muestra el triaje', (tester) async {
    final photo = CowPhoto(
      id: 'p1', cowId: 'c1', takenOn: DateTime(2026, 11, 9), fileName: 'p1.jpg', sizeBytes: 10,
      createdAt: DateTime(2026, 11, 9),
    );
    await tester.pumpWidget(MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => PhotoStore(Directory.systemTemp)),
        RepositoryProvider<PhotoRepository>(create: (_) => _MockPhotoRepository()),
      ],
      child: MaterialApp(home: PhotoViewScreen(photo: photo)),
    ));
    await tester.pump();
    expect(find.text('Para investigación (opcional)'), findsOneWidget);
    expect(find.byType(UdderTriageCard), findsNothing);
  });
}
