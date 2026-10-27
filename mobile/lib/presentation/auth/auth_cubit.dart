import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/remote/api_client.dart';
import '../../data/remote/auth_api.dart';
import '../../data/security/secure_store.dart';
import '../../domain/session.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthChecking extends AuthState {
  const AuthChecking();
}

class Unauthenticated extends AuthState {
  const Unauthenticated({this.busy = false, this.message});

  final bool busy;
  final String? message;

  @override
  List<Object?> get props => [busy, message];
}

class Authenticated extends AuthState {
  const Authenticated(this.session);

  final Session session;

  @override
  List<Object?> get props => [session];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({required this.store, required this.api, this.allowDemo = kDebugMode})
      : super(const AuthChecking());

  final SecureStore store;
  final AuthApi api;

  /// La entrada con datos de demostración solo existe en compilaciones debug.
  final bool allowDemo;

  /// Si ya hubo un ingreso, la sesión está guardada y la app abre sin necesitar conexión.
  Future<void> restore() async {
    final session = await store.readSession();
    emit(session == null ? const Unauthenticated() : Authenticated(session));
  }

  Future<void> login(String email, String password) =>
      _authenticate(() => api.login(email, password));

  Future<void> register(String name, String email, String password) =>
      _authenticate(() => api.register(name, email, password));

  Future<void> _authenticate(Future<Session> Function() call) async {
    emit(const Unauthenticated(busy: true));
    try {
      final session = await call();
      await store.saveSession(session);
      emit(Authenticated(session));
    } on ApiException catch (e) {
      emit(Unauthenticated(message: e.message));
    }
  }

  void enterDemo() {
    if (!allowDemo) return;
    emit(const Authenticated(Session(
      userId: Session.demoUserId,
      name: 'Ganadero de demostración',
      email: 'demo@agrovet.local',
      isDemo: true,
    )));
  }

  /// Cierra la sesión. Los datos locales (cifrados) se conservan para no perder lo que falte
  /// sincronizar; al volver a ingresar con la misma cuenta se recuperan.
  Future<void> logout() async {
    final current = state;
    if (current is Authenticated && !current.session.isDemo) {
      final refresh = current.session.refreshToken;
      if (refresh != null) await api.logout(refresh);
      await store.clearSession();
    }
    emit(const Unauthenticated());
  }

  /// El servidor rechazó la renovación: hay que ingresar de nuevo.
  Future<void> sessionExpired() async {
    await store.clearSession();
    emit(const Unauthenticated(message: 'Su sesión venció. Ingrese de nuevo para sincronizar.'));
  }
}
