import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/demo/demo_seed.dart';
import '../data/local/app_database.dart';
import '../data/local/database_opener.dart';
import '../data/local/local_repository.dart';
import '../data/security/secure_store.dart';
import '../domain/repositories.dart';
import '../domain/risk_evaluator.dart';
import '../domain/risk_predictor.dart';
import '../domain/session.dart';
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
  });

  final Session session;
  final Future<RiskPredictor> predictor;
  final Widget child;

  /// Permite inyectar una base en memoria en las pruebas.
  final Future<AppDatabase> Function(Session session)? openDatabase;

  @override
  State<SessionScope> createState() => _SessionScopeState();
}

class _SessionScopeState extends State<SessionScope> {
  late final Future<_SessionDeps> _deps;
  AppDatabase? _db;

  @override
  void initState() {
    super.initState();
    _deps = _open(context.read<SecureStore>());
  }

  Future<_SessionDeps> _open(SecureStore store) async {
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
    return _SessionDeps(repository, RiskEvaluator(await widget.predictor));
  }

  @override
  void dispose() {
    _db?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_SessionDeps>(
        future: _deps,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return LoadingView(message: 'No se pudo abrir la base de datos local.\n${snapshot.error}');
          }
          final deps = snapshot.data;
          if (deps == null) return const LoadingView(message: 'Abriendo sus datos…');
          return MultiRepositoryProvider(
            providers: [
              RepositoryProvider<Session>.value(value: widget.session),
              RepositoryProvider<LocalRepository>.value(value: deps.repository),
              RepositoryProvider<CowRepository>.value(value: deps.repository),
              RepositoryProvider<RecordRepository>.value(value: deps.repository),
              RepositoryProvider<InferenceRepository>.value(value: deps.repository),
              RepositoryProvider<RiskEvaluator>.value(value: deps.evaluator),
            ],
            child: widget.child,
          );
        },
      );
}

class _SessionDeps {
  _SessionDeps(this.repository, this.evaluator);

  final LocalRepository repository;
  final RiskEvaluator evaluator;
}
