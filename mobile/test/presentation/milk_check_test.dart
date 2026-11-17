import 'dart:io';
import 'dart:typed_data';

import 'package:agrovet/core/theme.dart';
import 'package:agrovet/data/ml/milk_model.dart';
import 'package:agrovet/data/photos/photo_capture.dart';
import 'package:agrovet/domain/milk_check.dart';
import 'package:agrovet/domain/session.dart';
import 'package:agrovet/presentation/milk/milk_check_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _Capture implements PhotoCapture {
  _Capture(this.result);

  final CaptureResult result;
  PhotoSource? asked;

  @override
  Future<CaptureResult> pick(PhotoSource source) async {
    asked = source;
    return result;
  }
}

void main() {
  group('zona del recuadro', () {
    test('sin mover la foto se analiza la foto entera', () {
      expect(cropBoxFor(Matrix4.identity(), 320, 640, 360), const CropBox(0, 0, 640, 360));
      expect(cropBoxFor(Matrix4.identity(), 300, 481, 640), const CropBox(0, 0, 481, 640));
    });

    test('al acercar al doble en el centro queda la mitad central', () {
      // Escala 2 alrededor del centro del recuadro de 320: se ve la zona [80, 240] del recuadro
      final transform = Matrix4.identity()
        ..translateByDouble(-160, -160, 0, 1)
        ..scaleByDouble(2, 2, 1, 1);
      // La foto de 640 x 640 ocupa el recuadro con escala 0,5: [80, 240] son los píxeles [160, 480]
      expect(cropBoxFor(transform, 320, 640, 640), const CropBox(160, 160, 480, 480));
    });

    test('lo que queda fuera de la foto no se cuenta', () {
      final transform = Matrix4.identity()..scaleByDouble(4, 4, 1, 1);
      // La foto de 640 x 360 está centrada con franjas negras arriba y abajo: la esquina superior
      // izquierda del recuadro cae en la franja
      final box = cropBoxFor(transform, 320, 640, 360);
      expect(box.left, 0);
      expect(box.top, 0);
      expect(box.right, 160);
      expect(box.bottom, lessThan(160));
    });
  });

  group('pantalla', () {
    late _Capture capture;
    Uint8List? received;

    Widget app({required CaptureResult result, DecodedImage? decoded}) {
      capture = _Capture(result);
      return MultiRepositoryProvider(
        providers: [
          RepositoryProvider<Session>.value(
            value: const Session(userId: 'demo', name: 'Demo', email: 'demo@agrovet.local', isDemo: true),
          ),
          RepositoryProvider<PhotoCapture>.value(value: capture),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: MilkCheckScreen(
            decode: (_) async => decoded ?? DecodedImage(481, 640, Uint8List(481 * 640 * 4)),
            estimator: (rgb) async {
              received = rgb;
              return const MilkCheckResult(0.87, 0.5);
            },
          ),
        ),
      );
    }

    testWidgets('el aviso fijo está siempre; elige de la galería, encuadra, analiza y muestra el resultado',
        (tester) async {
      final photo = File('../ml/tests/fixtures/milk/case_1.jpg').readAsBytesSync();
      await tester.pumpWidget(app(result: Captured(photo)));
      await tester.pumpAndSettle();

      expect(find.text(MilkCheckResult.disclaimer), findsOneWidget);
      expect(MilkCheckResult.disclaimer,
          'Experimental. No es diagnóstico. Solo validado con un conjunto de datos; con fotos nuevas puede fallar.');

      await tester.tap(find.text('Elegir de la galería'));
      await tester.pumpAndSettle();
      expect(capture.asked, PhotoSource.gallery);
      // Se abre la pantalla de encuadre, sin desplazamiento, con el recuadro
      expect(find.text('Encuadrar el pozo'), findsOneWidget);
      expect(find.byKey(const Key('milk-crop-frame')), findsOneWidget);
      // Círculo guía: el pozo ocupa 1/1,2 del recuadro, como el recorte del entrenamiento
      final frame = tester.getSize(find.byKey(const Key('milk-crop-frame')));
      final guide = tester.getSize(find.byKey(const Key('milk-guide')));
      expect(guide.width / (frame.width - 6), closeTo(1 / 1.2, 0.02));

      await tester.tap(find.text('Analizar el pozo del recuadro'));
      await tester.pumpAndSettle();

      expect(find.text('Leche (experimental)'), findsOneWidget);
      expect(received, hasLength(160 * 160 * 3));
      expect(find.text('Anormal'), findsOneWidget);
      expect(find.textContaining('87 %'), findsOneWidget);
      // El aviso arriba y otra vez junto al resultado
      expect(find.text(MilkCheckResult.disclaimer), findsNWidgets(2));
      expect(find.textContaining('la subclínica no se ve'), findsOneWidget);
    });

    testWidgets('al salir del encuadre sin analizar no hay resultado', (tester) async {
      final photo = File('../ml/tests/fixtures/milk/case_1.jpg').readAsBytesSync();
      received = null;
      await tester.pumpWidget(app(result: Captured(photo)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir de la galería'));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(received, isNull);
      expect(find.byKey(const Key('milk-result')), findsNothing);
      expect(find.text('Analizar otro pozo de esta foto'), findsOneWidget);
    });

    testWidgets('si no se pudo obtener la foto lo explica', (tester) async {
      await tester.pumpWidget(app(result: const CaptureFailed('AgroVet no tiene permiso para usar la cámara.')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tomar foto'));
      await tester.pumpAndSettle();
      expect(capture.asked, PhotoSource.camera);
      expect(find.textContaining('no tiene permiso'), findsOneWidget);
      expect(find.byKey(const Key('milk-crop-frame')), findsNothing);
    });

    testWidgets('con "Acercar" se analiza la zona central del recuadro', (tester) async {
      // Foto de 400 x 400 negra con un cuadrado blanco de 100 px en el centro
      final rgba = Uint8List(400 * 400 * 4);
      for (var y = 150; y < 250; y++) {
        for (var x = 150; x < 250; x++) {
          rgba.fillRange((y * 400 + x) * 4, (y * 400 + x) * 4 + 3, 255);
        }
      }
      double brightness(Uint8List rgb) => rgb.fold<int>(0, (a, v) => a + v) / rgb.length;
      final photo = File('../ml/tests/fixtures/milk/case_1.jpg').readAsBytesSync();
      await tester.pumpWidget(app(result: Captured(photo), decoded: DecodedImage(400, 400, rgba)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir de la galería'));
      await tester.pumpAndSettle();

      Future<double> analyze() async {
        await tester.tap(find.text('Analizar el pozo del recuadro'));
        await tester.pumpAndSettle();
        return brightness(received!);
      }

      final whole = await analyze();
      expect(whole, closeTo(255 / 16, 2)); // el cuadrado blanco es 1/16 de la foto

      await tester.ensureVisible(find.text('Analizar otro pozo de esta foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analizar otro pozo de esta foto'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byTooltip('Acercar'));
        await tester.pumpAndSettle();
      }
      final zoomed = await analyze();
      // Con 1,25^4 = 2,44 se ven unos 164 px del centro: el blanco ocupa (100/164)^2 = 37 %
      expect(zoomed, closeTo(255 * 0.37, 12));

      await tester.ensureVisible(find.text('Analizar otro pozo de esta foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analizar otro pozo de esta foto'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('Acercar'));
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.byTooltip('Alejar'));
        await tester.pumpAndSettle();
      }
      // No se aleja más que la foto entera
      expect(await analyze(), closeTo(whole, 0.5));
    });
  });
}
