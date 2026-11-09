import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

import '../data/demo/demo_seed.dart';
import '../data/local/app_database.dart';
import '../data/local/database_opener.dart';
import '../data/local/local_data_wiper.dart';
import '../data/local/local_repository.dart';
import '../data/photos/photo_capture.dart';
import '../data/photos/photo_store.dart';
import '../data/remote/api_client.dart';
import '../data/remote/online_status.dart';
import '../data/remote/profile_api.dart';
import '../data/security/secure_store.dart';
import '../data/sync/sync_service.dart';
import '../domain/repositories.dart';
import '../domain/risk_evaluator.dart';
import '../domain/risk_predictor.dart';
import '../domain/session.dart';
import 'sync/sync_cubit.dart';
import 'widgets/loading_view.dart';

/// Abre la base cifrada del usuario y entrega los repositorios a las pantallas de la sesión.
/// Cada usuario tiene su propio archivo y su propia clave: nadie ve datos de otro en el mismo celular.
class SessionScope extends StatefulWidget {
  const SessionScope({
    super.key,
    required this.session,
    required this.predictor,
    required this.child,
    this.openDatabase,
    this.connectivity,
    this.photosRoot,
    this.photoCapture,
  });

  /// Carpeta base de las fotos; por defecto, el almacenamiento privado de la app.
  final Future<Directory> Function()? photosRoot;

  /// Captura de fotos; por defecto, la cámara y la galería del sistema.
  final PhotoCapture? photoCapture;

  final Session session;
  final Future<RiskPredictor> predictor;
  final Widget child;

  /// Permite inyectar una base en memoria en las pruebas.
  final Future<AppDatabase> Function(Session session)? openDatabase;

  /// true cuando hay red. Por defecto, connectivity_plus.
  final Stream<bool>? connectivity;

  @override
  State<SessionScope> createState() => _SessionScopeState();
}

class _SessionScopeState extends State<SessionScope> {
  late final Future<_SessionDeps> _deps;
  AppDatabase? _db;
  Future<void>? _closing;

  // Al volver la app al frente se sincroniza lo pendiente
  final _resumed = StreamController<void>.broadcast();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => _resumed.add(null));
    _deps = _open(context.read<SecureStore>(), context.read<ApiClient>());
  }

  Future<_SessionDeps> _open(SecureStore store, ApiClient api) async {
    final session = widget.session;
    final db = widget.openDatabase != null
        ? await widget.openDatabase!(session)
        : await DatabaseOpener.openForUser(
            userId: session.userId,
            hexKey: await store.databaseKeyFor(session.userId),
          );
    _db = db;
    final repository = LocalRepository(db, isDemo: session.isDemo);
    if (session.isDemo && kDebugMode) {
      await DemoSeed(repository).seedIfEmpty();
    }
    final photos = await PhotoStore.forUser(
      widget.photosRoot != null
          ? await widget.photosRoot!()
          : await getApplicationSupportDirectory(),
      session.userId,
    );
    final online = OnlineStatus(
      (widget.connectivity ?? _online()).asBroadcastStream(),
      initial: widget.connectivity != null || await _isOnlineNow(),
    );
    final sync = session.isDemo
        ? SyncCubit.disabled()
        : (SyncCubit(
            SyncService(db, SyncApi(api), photos: photos),
            connectivity: online.changes,
            appResumed: _resumed.stream,
            initiallyOnline: online.online,
            loadLastSync: () => store.lastSyncFor(session.userId),
            saveLastSync: (at) => store.saveLastSync(session.userId, at),
          ));
    final wiper = LocalDataWiper(() async {
      await _closeDatabase();
      if (widget.openDatabase == null) {
        await DatabaseOpener.deleteForUser(session.userId);
      }
      await photos.deleteAll();
      await store.forgetUser(session.userId);
    });
    return _SessionDeps(
      repository,
      RiskEvaluator(await widget.predictor),
      sync,
      wiper,
      photos,
      online,
    );
  }

  /// Cierra la base una sola vez. Salir de la sesión y borrar los datos esperan el mismo cierre, así
  /// el archivo nunca se borra mientras sigue abierto.
  Future<void> _closeDatabase() =>
      _closing ??= _db?.close() ?? Future<void>.value();

  static Future<bool> _isOnlineNow() async =>
      (await Connectivity().checkConnectivity()).any(
        (r) => r != ConnectivityResult.none,
      );

  static Stream<bool> _online() => Connectivity().onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );

  @override
  void dispose() {
    _lifecycle.dispose();
    _resumed.close();
    _deps
        .then((deps) async {
          await deps.sync.close();
          await deps.online.dispose();
        })
        .whenComplete(_closeDatabase);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_SessionDeps>(
    future: _deps,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return LoadingView(
          message:
              'No se pudo abrir la base de datos local.\n${snapshot.error}',
        );
      }
      final deps = snapshot.data;
      if (deps == null) {
        return const LoadingView(message: 'Abriendo sus datos…');
      }
      return MultiRepositoryProvider(
        providers: [
          RepositoryProvider<Session>.value(value: widget.session),
          RepositoryProvider<LocalRepository>.value(value: deps.repository),
          RepositoryProvider<CowRepository>.value(value: deps.repository),
          RepositoryProvider<RecordRepository>.value(value: deps.repository),
          RepositoryProvider<InferenceRepository>.value(value: deps.repository),
          RepositoryProvider<AlertRepository>.value(value: deps.repository),
          RepositoryProvider<RiskEvaluator>.value(value: deps.evaluator),
          RepositoryProvider<LocalDataWiper>.value(value: deps.wiper),
          RepositoryProvider<PhotoRepository>.value(value: deps.repository),
          RepositoryProvider<AssistantRepository>.value(value: deps.repository),
          RepositoryProvider<OnlineStatus>.value(value: deps.online),
          RepositoryProvider<PhotoStore>.value(value: deps.photos),
          RepositoryProvider<PhotoCapture>(
            create: (_) => widget.photoCapture ?? SystemPhotoCapture(),
          ),
          RepositoryProvider<ProfileApi>(
            create: (context) => ProfileApi(context.read<ApiClient>()),
          ),
        ],
        child: BlocProvider<SyncCubit>.value(
          value: deps.sync,
          child: widget.child,
        ),
      );
    },
  );
}

class _SessionDeps {
  _SessionDeps(
    this.repository,
    this.evaluator,
    this.sync,
    this.wiper,
    this.photos,
    this.online,
  );

  final LocalRepository repository;
  final RiskEvaluator evaluator;
  final SyncCubit sync;
  final LocalDataWiper wiper;
  final PhotoStore photos;
  final OnlineStatus online;
}
