import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/responsive.dart';
import 'core/theme.dart';
import 'data/ml/risk_model.dart';
import 'data/remote/api_client.dart';
import 'data/remote/auth_api.dart';
import 'data/security/secure_store.dart';
import 'domain/risk_predictor.dart';
import 'presentation/auth/auth_cubit.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/cows/cows_screen.dart';
import 'presentation/session_scope.dart';
import 'presentation/widgets/loading_view.dart';

class AgroVetApp extends StatefulWidget {
  const AgroVetApp({super.key, required this.store, required this.apiClient, this.predictor});

  final SecureStore store;
  final ApiClient apiClient;

  /// Permite inyectar un modelo falso en las pruebas de interfaz.
  final Future<RiskPredictor>? predictor;

  @override
  State<AgroVetApp> createState() => _AgroVetAppState();
}

class _AgroVetAppState extends State<AgroVetApp> {
  late final AuthCubit _auth = AuthCubit(store: widget.store, api: AuthApi(widget.apiClient))..restore();

  /// El modelo se carga una sola vez y se comparte entre sesiones.
  late final Future<RiskPredictor> _predictor = widget.predictor ?? RiskModel.load();

  @override
  void initState() {
    super.initState();
    widget.apiClient.onSessionExpired = _auth.sessionExpired;
  }

  @override
  void dispose() {
    _auth.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider.value(value: widget.store),
          RepositoryProvider.value(value: widget.apiClient),
        ],
        child: BlocProvider.value(
          value: _auth,
          child: MaterialApp(
            title: 'AgroVet',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            locale: const Locale('es'),
            supportedLocales: const [Locale('es'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: _AuthGate(predictor: _predictor),
          ),
        ),
      );
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({required this.predictor});

  final Future<RiskPredictor> predictor;

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthCubit, AuthState>(
        buildWhen: (previous, current) => previous.runtimeType != current.runtimeType ||
            (previous is Authenticated && current is Authenticated && previous.session.userId != current.session.userId),
        builder: (context, state) => AnimatedSwitcher(
          duration: Responsive.motion(context, const Duration(milliseconds: 400)),
          child: switch (state) {
            AuthChecking() => const LoadingView(key: ValueKey('checking'), message: 'Cargando…'),
            Unauthenticated() => const LoginScreen(key: ValueKey('login')),
            Authenticated(:final session) => SessionScope(
                key: ValueKey('session-${session.userId}'),
                session: session,
                predictor: predictor,
                child: const SessionNavigator(),
              ),
          },
        ),
      );
}

/// Navegación propia de la sesión: las pantallas ven los repositorios del usuario y todo se
/// cierra junto al salir. El botón atrás de Android retrocede dentro de esta pila.
class SessionNavigator extends StatefulWidget {
  const SessionNavigator({super.key});

  @override
  State<SessionNavigator> createState() => _SessionNavigatorState();
}

class _SessionNavigatorState extends State<SessionNavigator> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _heroController = MaterialApp.createMaterialHeroController();

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NavigatorPopHandler<Object?>(
        onPopWithResult: (_) => _navigatorKey.currentState?.maybePop(),
        child: HeroControllerScope(
          controller: _heroController,
          child: Navigator(
            key: _navigatorKey,
            onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const CowsScreen()),
          ),
        ),
      );
}
