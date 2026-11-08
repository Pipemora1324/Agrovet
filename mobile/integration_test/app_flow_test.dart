// Recorrido completo en el dispositivo con la app real (almacenamiento seguro, SQLCipher y modelo TFLite).
// Uso: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_flow_test.dart
// Las capturas quedan en build/screenshots (o en SCREENSHOT_DIR).
//
// La prueba de cuenta real lee el código de verificación en Mailpit. En el emulador Mailpit está en
// 10.0.2.2:8025; en un celular por USB, `adb reverse tcp:8025 tcp:8025` y
// --dart-define=MAILPIT_URL=http://localhost:8025.
import 'package:agrovet/main.dart' as app;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _mailpitUrl = String.fromEnvironment('MAILPIT_URL', defaultValue: 'http://10.0.2.2:8025');

/// Código de 6 números del último correo que llegó a Mailpit para esa dirección.
Future<String> mailpitCode(String email) async {
  final dio = Dio(BaseOptions(baseUrl: _mailpitUrl));
  for (var attempt = 0; attempt < 20; attempt++) {
    final search = await dio.get<Map<String, dynamic>>('/api/v1/search', queryParameters: {'query': 'to:"$email"'});
    final messages = (search.data!['messages'] as List).cast<Map<String, dynamic>>();
    if (messages.isNotEmpty) {
      final message = await dio.get<Map<String, dynamic>>('/api/v1/message/${messages.first['ID']}');
      final match = RegExp(r'\b(\d{6})\b').firstMatch(message.data!['Text'] as String);
      if (match != null) return match.group(1)!;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  throw StateError('No llegó el código a Mailpit para $email');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
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

  testWidgets('demostración: vacas, captura, semáforo e historial', (tester) async {
    await app.main();
    await settle(tester);

    expect(find.text('Ver con datos de demostración'), findsOneWidget);
    await shot(tester, '01_login');

    await tester.tap(find.text('Ver con datos de demostración'));
    await settle(tester, seconds: 4);
    expect(find.text('Datos de demostración'), findsOneWidget);
    expect(find.text('Canela'), findsOneWidget);
    await shot(tester, '02_vacas');

    await tester.tap(find.text('Canela'));
    await settle(tester);
    expect(find.text('Registro de hoy'), findsOneWidget);
    await shot(tester, '03_ficha');

    await tester.tap(find.text('Registro de hoy'));
    await settle(tester);
    expect(find.text('¿Ve alguno de estos signos en la ubre?'), findsOneWidget);
    expect(find.text('Ya hay un registro para este día: puede corregirlo.'), findsOneWidget);
    await shot(tester, '04_registro');
    await tester.scrollUntilVisible(find.text('Guardar registro'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Guardar registro'));
    await settle(tester);
    expect(find.text('Evaluar riesgo'), findsOneWidget);

    await tester.tap(find.text('Evaluar riesgo'));
    await settle(tester, seconds: 3);
    expect(find.text('Esta herramienta apoya, no reemplaza al veterinario.'), findsOneWidget);
    expect(find.textContaining('Probabilidad estimada'), findsOneWidget);
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
    await tester.tap(find.text('Paloma'));
    await settle(tester);
    await tester.tap(find.text('Evaluar riesgo'));
    await settle(tester, seconds: 3);
    expect(find.text('Faltan registros'), findsOneWidget);
    await shot(tester, '07_faltan_datos');
  });

  // Requiere el backend del docker-compose corriendo en el equipo (10.0.2.2:8080 desde el emulador)
  testWidgets('cuenta real: crear cuenta, agregar una vaca y cerrar sesión', (tester) async {
    await app.main();
    await settle(tester);

    await tester.tap(find.text('No tengo cuenta: crear una'));
    await settle(tester);
    final email = 'emulador${DateTime.now().millisecondsSinceEpoch}@correo.co';
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Ganadero de prueba');
    await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), email);
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'clave-segura-1');
    await acceptPrivacyAndRegister(tester);

    // Pantalla del código: se lee el correo que recibió Mailpit en el equipo
    expect(find.text('Revise su correo'), findsOneWidget);
    expect(find.textContaining('Reenviar código en'), findsOneWidget);
    await shot(tester, '08_verificar_correo');
    final code = await mailpitCode(email);
    await tester.enterText(find.widgetWithText(TextFormField, 'Código'), code);
    await settle(tester, seconds: 5);
    expect(find.text('Todavía no hay vacas'), findsOneWidget);
    expect(find.text('Datos de demostración'), findsNothing);

    await tester.tap(find.text('Agregar vaca'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Identificador (arete) *'), 'F-100');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Rosita');
    await tester.scrollUntilVisible(find.text('Guardar'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Guardar'));
    await settle(tester);
    expect(find.text('Rosita'), findsOneWidget);

    // Registro del día para que también viaje un registro diario
    await tester.tap(find.text('Rosita'));
    await settle(tester);
    await tester.tap(find.text('Registro de hoy'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Temperatura (opcional)'), '38,7');
    await tester.enterText(find.widgetWithText(TextFormField, 'Leche del día (opcional)'), '11,5');
    await tester.enterText(find.widgetWithText(TextFormField, 'Alimento consumido (opcional)'), '9');
    await tester.scrollUntilVisible(find.text('Guardar registro'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Guardar registro'));
    await settle(tester);
    await back(tester);
    await settle(tester);

    // Sincronización manual: la nube abre el estado del respaldo con los 2 cambios pendientes
    expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
    await tester.tap(find.byIcon(Icons.cloud_upload));
    await settle(tester);
    expect(find.text('Hay cambios por subir'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    await tester.tap(find.text('Sincronizar ahora'));
    // El aviso dura 4 s: se busca mientras la respuesta llega, antes de que se oculte
    final saved = find.text('Datos respaldados en el servidor.');
    for (var i = 0; i < 30 && saved.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(saved, findsOneWidget);
    await settle(tester, seconds: 5);
    expect(find.text('Todo respaldado'), findsOneWidget);
    expect(find.textContaining('Hoy, '), findsOneWidget);
    await back(tester);
    expect(find.byIcon(Icons.cloud_done), findsOneWidget);
    // EMAIL_SINCRONIZADO lo lee la verificación hecha desde el equipo contra PostgreSQL
    debugPrint('EMAIL_SINCRONIZADO=$email');

    // Cerrar sesión ahora está en "Mi perfil"
    await tester.tap(find.byTooltip('Mi perfil'));
    await settle(tester);
    await reveal(tester, find.text('Cerrar sesión'));
    await tester.tap(find.text('Cerrar sesión'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
    await settle(tester, seconds: 3);
    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('cuenta real: editar el perfil y eliminar la cuenta con sus datos', (tester) async {
    await app.main();
    await settle(tester);

    await tester.tap(find.text('No tengo cuenta: crear una'));
    await settle(tester);
    final email = 'borrar${DateTime.now().millisecondsSinceEpoch}@correo.co';
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Cuenta para borrar');
    await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), email);
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'clave-segura-1');
    await acceptPrivacyAndRegister(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Código'), await mailpitCode(email));
    await settle(tester, seconds: 5);

    // Una vaca sincronizada, para comprobar que también se borra del servidor
    await tester.tap(find.text('Agregar vaca'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Identificador (arete) *'), 'B-1');
    await tester.scrollUntilVisible(find.text('Guardar'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Guardar'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.cloud_upload));
    await settle(tester);
    await tester.tap(find.text('Sincronizar ahora'));
    await settle(tester, seconds: 5);
    expect(find.text('Todo respaldado'), findsOneWidget);
    await back(tester);

    await tester.tap(find.byTooltip('Mi perfil'));
    await settle(tester, seconds: 3);
    expect(find.text(email), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Municipio (opcional)'), 'Pasto');
    await tester.enterText(find.widgetWithText(TextFormField, 'Finca (opcional)'), 'La Esperanza');
    await reveal(tester, find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await settle(tester, seconds: 3);
    await shot(tester, '09_perfil');

    await reveal(tester, find.text('Eliminar mi cuenta'));
    await tester.tap(find.text('Eliminar mi cuenta'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Su contraseña'), 'clave-segura-1');
    await shot(tester, '10_eliminar_cuenta');
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await settle(tester, seconds: 5);
    expect(find.text('Su cuenta y todos sus datos fueron eliminados.'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
    // EMAIL_ELIMINADO lo comprueba la verificación hecha desde el equipo contra PostgreSQL
    debugPrint('EMAIL_ELIMINADO=$email');
  });
}

/// Lleva el widget a la vista. ensureVisible desplaza pero no dibuja: sin el pump, el toque usaría
/// la posición anterior.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
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
