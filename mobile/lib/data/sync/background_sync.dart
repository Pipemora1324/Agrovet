import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/config.dart';
import '../local/database_opener.dart';
import '../remote/api_client.dart';
import '../security/secure_store.dart';
import 'sync_service.dart';

const _periodicTaskName = 'agrovet-sync';
const _periodicUniqueName = 'agrovet-periodic-sync';

/// Punto de entrada del proceso en segundo plano de Android (WorkManager).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    return runBackgroundSync();
  });
}

/// Sube lo pendiente de la sesión guardada. Devolver false le pide a Android reintentar más tarde
/// con espera exponencial; los datos siguen a salvo en el celular.
Future<bool> runBackgroundSync() async {
  final store = SecureStore();
  final session = await store.readSession();
  if (session == null || session.isDemo || session.refreshToken == null) return true;

  final db = await DatabaseOpener.openForUser(
    userId: session.userId,
    hexKey: await store.databaseKeyFor(session.userId),
  );
  try {
    final client = ApiClient(baseUrl: AppConfig.apiBaseUrl, store: store);
    final report = await SyncService(db, SyncApi(client)).syncNow();
    if (report.ok) await store.saveLastSync(session.userId, DateTime.now());
    return report.ok;
  } finally {
    await db.close();
  }
}

class BackgroundSync {
  /// Programa la sincronización periódica (cada 15 minutos, el mínimo de Android) solo con red.
  static Future<void> schedule() async {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      _periodicUniqueName,
      _periodicTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 1),
    );
  }
}
