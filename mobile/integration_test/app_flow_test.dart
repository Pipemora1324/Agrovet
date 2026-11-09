// Recorrido completo en el dispositivo con la app real (almacenamiento seguro, SQLCipher y modelo TFLite).
// Uso: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_flow_test.dart
// Las capturas quedan en build/screenshots (o en SCREENSHOT_DIR).
//
// La prueba de cuenta real lee el código de verificación en Mailpit. En el emulador Mailpit está en
// 10.0.2.2:8025; en un celular por USB, `adb reverse tcp:8025 tcp:8025` y
// --dart-define=MAILPIT_URL=http://localhost:8025.
import 'package:agrovet/core/theme.dart';
import 'package:agrovet/domain/repositories.dart';
import 'package:agrovet/main.dart' as app;
import 'package:agrovet/presentation/assistant/assistant_screen.dart';
import 'package:agrovet/presentation/auth/code_field.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _mailpitUrl = String.fromEnvironment(
  'MAILPIT_URL',
  defaultValue: 'http://10.0.2.2:8025',
);

/// Código de 6 números del último correo que llegó a Mailpit para esa dirección.
Future<String> mailpitCode(String email) async {
  final dio = Dio(BaseOptions(baseUrl: _mailpitUrl));
  for (var attempt = 0; attempt < 20; attempt++) {
    final search = await dio.get<Map<String, dynamic>>(
      '/api/v1/search',
      queryParameters: {'query': 'to:"$email"'},
    );
    final messages = (search.data!['messages'] as List)
        .cast<Map<String, dynamic>>();
    if (messages.isNotEmpty) {
      final message = await dio.get<Map<String, dynamic>>(
        '/api/v1/message/${messages.first['ID']}',
      );
      final match = RegExp(r'\b(\d{6})\b')
          .firstMatch(message.data!['Text'] as String);
      if (match != null) return match.group(1)!;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  throw StateError('No llegó el código a Mailpit para $email');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Las animaciones que se repiten hacen un solo ciclo, para que pumpAndSettle termine
  AppMotion.ambient = false;
  var surfaceConverted = false;
  // El binding revierte la conversión de la superficie al terminar cada prueba
  setUp(() => surfaceConverted = false);

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    if (!surfaceConverted) {
      // En Android la superficie se convierte una sola vez para poder capturarla
      await binding.convertFlutterSurfaceToImage();
      surfaceConverted = true;
      await tester.pumpAndSettle();
    }
    await binding.takeScreenshot(name);
  }

  // Retrocede en el navegador de la sesión (el anidado dentro de la app)
  Future<void> back(WidgetTester tester) async {
    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    await tester.pumpAndSettle();
  }

  Future<void> settle(WidgetTester tester, {int seconds = 2}) async {
    for (var i = 0; i < seconds * 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('demostración: vacas, captura, semáforo e historial', (
    tester,
  ) async {
    await app.main();
    await settle(tester);

    expect(find.text('Entrar a la demostración'), findsOneWidget);
    await shot(tester, '01_login');

    await tester.tap(find.text('Entrar a la demostración'));
    await settle(tester, seconds: 4);
    expect(find.text('Modo de prueba'), findsOneWidget);
    expect(find.text('Canela'), findsOneWidget);
    await shot(tester, '02_vacas');

    await tester.tap(find.text('Canela'));
    await settle(tester);
    expect(find.text('Registro de hoy'), findsOneWidget);
    await shot(tester, '03_ficha');

    await reveal(tester, find.text('Registro de hoy'));
    await tester.tap(find.text('Registro de hoy'));
    await settle(tester);
    // Asistente por preguntas: una por pantalla, pasa sola al tocar una opción
    // (El aviso "Ya hay un registro…" depende de la fecha en que se sembró la demostración)
    expect(find.text('¿Cómo comió hoy?'), findsOneWidget);
    await shot(tester, '04_registro');
    await answer(tester, 'Normal');
    await answer(tester, 'Igual');
    await answer(tester, 'Normal');
    await answer(tester, 'Leche con grumos o sangre');
    expect(find.text('¡Listo!'), findsOneWidget);
    await shot(tester, '04b_registro_final');
    await reveal(tester, find.text('Guardar registro'));
    await tester.tap(find.text('Guardar registro'));
    await settle(tester);
    expect(find.text('Evaluar riesgo'), findsOneWidget);

    await reveal(tester, find.text('Evaluar riesgo'));
    await tester.tap(find.text('Evaluar riesgo'));
    await settle(tester, seconds: 3);
    expect(
      find.text('Esta herramienta apoya, no reemplaza al veterinario.'),
      findsOneWidget,
    );
    expect(find.textContaining('Probabilidad estimada'), findsNothing);
    expect(find.text('Grumos o sangre en la leche (+3)'), findsOneWidget);
    expect(find.text('Sin señales de alerta.'), findsOneWidget);
    await shot(tester, '05_semaforo');

    await back(tester);
    await settle(tester);

    // La evaluación en rojo deja una alerta en la ficha; se marca como atendida
    final attend = find.text('Marcar como atendida');
    final pendingAlerts = attend.evaluate().length;
    expect(pendingAlerts, greaterThan(0));
    await shot(tester, '05b_alerta');
    await tester.ensureVisible(attend.first);
    await tester.tap(attend.first);
    await settle(tester);
    expect(find.text('Marcar como atendida'), findsNWidgets(pendingAlerts - 1));

    await tester.ensureVisible(find.text('Ver historial'));
    await tester.tap(find.text('Ver historial'));
    await settle(tester, seconds: 3);
    expect(find.text('Temperatura (°C)'), findsOneWidget);
    expect(find.text('Evaluaciones del semáforo'), findsOneWidget);
    await shot(tester, '06_historial');

    await back(tester);
    await settle(tester);
    await back(tester);
    await settle(tester);
    // Paloma tiene pocos días con mediciones: el semáforo se apoya en los síntomas de hoy
    await reveal(tester, find.text('Paloma'));
    await tester.tap(find.text('Paloma'));
    await settle(tester);
    await reveal(tester, find.text('Evaluar riesgo'));
    await tester.tap(find.text('Evaluar riesgo'));
    await settle(tester, seconds: 3);
    expect(
      find.text(
        'Aún hay pocos registros anteriores. El semáforo se basa en los signos de hoy.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Revise la vaca y siga las recomendaciones.'),
      findsOneWidget,
    );
    await shot(tester, '07_solo_sintomas');

    // Luna no tiene registros: no hay nada que evaluar
    await back(tester);
    await settle(tester);
    await back(tester);
    await settle(tester);
    await reveal(tester, find.text('Luna'));
    await tester.tap(find.text('Luna'));
    await settle(tester);
    await reveal(tester, find.text('Evaluar riesgo'));
    await tester.tap(find.text('Evaluar riesgo'));
    await settle(tester, seconds: 3);
    expect(find.text('Faltan registros'), findsOneWidget);
    await shot(tester, '07b_faltan_registros');
  });

  // Requiere el backend del docker-compose corriendo en el equipo (10.0.2.2:8080 desde el emulador)
  testWidgets('cuenta real: crear cuenta, agregar una vaca y cerrar sesión', (
    tester,
  ) async {
    await app.main();
    await settle(tester);

    await reveal(tester, find.text('No tengo cuenta: crear una'));
    await tester.tap(find.text('No tengo cuenta: crear una'));
    await settle(tester);
    final email = 'emulador${DateTime.now().millisecondsSinceEpoch}@correo.co';
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre'),
      'Ganadero de prueba',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), email);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'clave-segura-1',
    );
    await acceptPrivacyAndRegister(tester);

    // Pantalla del código: se lee el correo que recibió Mailpit en el equipo
    expect(find.text('Revise su correo'), findsOneWidget);
    expect(find.textContaining('Reenviar código en'), findsOneWidget);
    await shot(tester, '08_verificar_correo');
    final code = await mailpitCode(email);
    await tester.enterText(find.byType(CodeField), code);
    await settle(tester, seconds: 5);
    expect(find.text('Todavía no hay vacas'), findsOneWidget);
    expect(find.text('Modo de prueba'), findsNothing);

    await tester.tap(find.text('Agregar vaca'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Identificador (arete) *'),
      'F-100',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre'),
      'Rosita',
    );
    await tester.scrollUntilVisible(
      find.text('Guardar'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Guardar'));
    await settle(tester);
    expect(find.text('Rosita'), findsOneWidget);

    // Registro del día para que también viaje un registro diario
    await tester.tap(find.text('Rosita'));
    await settle(tester);
    await reveal(tester, find.text('Registro de hoy'));
    await tester.tap(find.text('Registro de hoy'));
    await settle(tester);
    await answer(tester, 'Normal');
    await answer(tester, 'Igual');
    await answer(tester, 'Normal');
    await answer(tester, 'Todo normal');
    // Con termómetro y litros exactos se guardan como medidos
    await answer(tester, 'Tengo termómetro o litros exactos');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Temperatura (opcional)'),
      '38,7',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Leche del día (opcional)'),
      '11,5',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Alimento consumido (opcional)'),
      '9',
    );
    // El teclado abierto tapa el botón: se cierra antes de tocarlo
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    expect(find.text('medido'), findsNWidgets(3));
    await reveal(tester, find.text('Guardar registro'));
    await tester.tap(find.text('Guardar registro'));
    await settle(tester);

    await reveal(tester, find.text('Fotos'));
    await tester.tap(find.text('Fotos'));
    await settle(tester);
    await tester.tap(find.text('Agregar foto'));
    await settle(tester);
    await tester.tap(find.text('Tomar foto con la cámara'));
    final savedMessage = find.text('Foto guardada.');
    for (var attempt = 0; attempt < 120 && savedMessage.evaluate().isEmpty; attempt++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(savedMessage, findsOneWidget);
    expect(
      find.text('Las fotos quedan guardadas como registros de esta vaca.'),
      findsOneWidget,
    );
    await shot(tester, '11_foto_guardada');
    final photoTile = find.bySemanticsLabel(RegExp('Foto del'));
    await tester.tap(photoTile);
    await settle(tester);
    await tester.tap(find.byTooltip('Borrar foto'));
    await settle(tester);
    await tester.tap(find.text('Borrar'));
    await settle(tester);
    expect(find.text('Foto borrada.'), findsOneWidget);
    await back(tester);
    await settle(tester);

    await reveal(tester, find.text('Preguntar al asistente'));
    await tester.tap(find.text('Preguntar al asistente'));
    await settle(tester);
    final assistant = tester.element(find.byType(AssistantScreen));
    final cowId = tester
        .widget<AssistantScreen>(find.byType(AssistantScreen))
        .cow
        .id;
    final conversation = assistant.read<AssistantRepository>().watchMessages(
      cowId,
    );
    final response = conversation.firstWhere(
      (messages) => messages.length >= 2,
    );
    await tester.enterText(
      find.byType(TextField).last,
      '¿Qué debo observar hoy?',
    );
    await tester.tap(find.byTooltip('Enviar'));
    final messages = await response.timeout(const Duration(seconds: 70));
    expect(messages.last.fromUser, isFalse);
    expect(messages.last.text.trim(), isNotEmpty);
    debugPrint('RESPUESTA_ASISTENTE=${messages.last.text}');
    await back(tester);
    await settle(tester);

    await back(tester);
    await settle(tester);
    final syncStatus = find.textContaining('Última sincronización: hace');
    for (
      var attempt = 0;
      attempt < 50 && syncStatus.evaluate().isEmpty;
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(syncStatus, findsOneWidget);
    // EMAIL_SINCRONIZADO lo lee la verificación hecha desde el equipo contra PostgreSQL
    debugPrint('EMAIL_SINCRONIZADO=$email');

    // Cerrar sesión está en la pestaña "Perfil"
    await tester.tap(find.text('Perfil'));
    await settle(tester);
    await reveal(tester, find.text('Cerrar sesión'));
    await tester.tap(find.text('Cerrar sesión'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
    await settle(tester, seconds: 3);
    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets(
    'cuenta real: editar el perfil y eliminar la cuenta con sus datos',
    (tester) async {
      await app.main();
      await settle(tester);

      await reveal(tester, find.text('No tengo cuenta: crear una'));
      await tester.tap(find.text('No tengo cuenta: crear una'));
      await settle(tester);
      final email = 'borrar${DateTime.now().millisecondsSinceEpoch}@correo.co';
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Cuenta para borrar',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'),
        email,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'clave-segura-1',
      );
      await acceptPrivacyAndRegister(tester);
      await tester.enterText(find.byType(CodeField), await mailpitCode(email));
      await settle(tester, seconds: 5);

      // Una vaca sincronizada, para comprobar que también se borra del servidor
      await tester.tap(find.text('Agregar vaca'));
      await settle(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Identificador (arete) *'),
        'B-1',
      );
      await tester.scrollUntilVisible(
        find.text('Guardar'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Guardar'));
      await settle(tester);
      final syncStatus = find.textContaining('Última sincronización: hace');
      for (
        var attempt = 0;
        attempt < 50 && syncStatus.evaluate().isEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(syncStatus, findsOneWidget);

      await tester.tap(find.text('Perfil'));
      await settle(tester, seconds: 3);
      expect(find.text(email), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Municipio (opcional)'),
        'Pasto',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Finca (opcional)'),
        'La Esperanza',
      );
      await reveal(tester, find.text('Guardar cambios'));
      await tester.tap(find.text('Guardar cambios'));
      await settle(tester, seconds: 3);
      await shot(tester, '09_perfil');

      await reveal(tester, find.text('Eliminar mi cuenta'));
      await tester.tap(find.text('Eliminar mi cuenta'));
      await settle(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Su contraseña'),
        'clave-segura-1',
      );
      await shot(tester, '10_eliminar_cuenta');
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await settle(tester, seconds: 5);
      expect(
        find.text('Su cuenta y todos sus datos fueron eliminados.'),
        findsOneWidget,
      );
      expect(find.text('Ingresar'), findsOneWidget);
      // EMAIL_ELIMINADO lo comprueba la verificación hecha desde el equipo contra PostgreSQL
      debugPrint('EMAIL_ELIMINADO=$email');
    },
  );
}

/// Lleva el widget a la vista. ensureVisible desplaza pero no dibuja: sin el pump, el toque usaría
/// la posición anterior.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

/// Toca una opción del asistente del registro (pasa sola a la siguiente pregunta).
Future<void> answer(WidgetTester tester, String option) async {
  await reveal(tester, find.text(option));
  await tester.tap(find.text(option));
  await tester.pumpAndSettle();
}

/// Marca el consentimiento del aviso de privacidad y toca "Crear cuenta".
Future<void> acceptPrivacyAndRegister(WidgetTester tester) async {
  await reveal(tester, find.byType(Checkbox));
  await tester.tap(find.byType(Checkbox));
  await tester.pumpAndSettle();
  await reveal(tester, find.text('Crear cuenta'));
  await tester.tap(find.text('Crear cuenta'));
  for (var i = 0; i < 50; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}
