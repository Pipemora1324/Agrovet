import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'core/config.dart';
import 'data/remote/api_client.dart';
import 'data/security/secure_store.dart';
import 'data/sync/background_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  Intl.defaultLocale = 'es';

  // Sin una dirección válida del servidor no se arranca: se explica cómo compilar la app
  final problem = AppConfig.problem;
  if (problem != null) {
    runApp(ConfigErrorApp(message: problem));
    return;
  }

  if (Platform.isAndroid) {
    // Si no se puede programar, la app sincroniza igual en primer plano
    unawaited(BackgroundSync.schedule().catchError((Object _) {}));
  }

  final store = SecureStore();
  runApp(AgroVetApp(store: store, apiClient: ApiClient(baseUrl: AppConfig.apiBaseUrl, store: store)));
}
