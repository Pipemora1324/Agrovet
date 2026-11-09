import 'dart:async';

import 'package:agrovet/core/theme.dart';

/// Configuración común de las pruebas: las animaciones que se repiten hacen un solo ciclo, así
/// pumpAndSettle termina.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppMotion.ambient = false;
  await testMain();
}
