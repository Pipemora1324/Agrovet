import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'core/config.dart';
import 'data/remote/api_client.dart';
import 'data/security/secure_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  Intl.defaultLocale = 'es';

  final store = SecureStore();
  runApp(AgroVetApp(store: store, apiClient: ApiClient(baseUrl: AppConfig.apiBaseUrl, store: store)));
}
