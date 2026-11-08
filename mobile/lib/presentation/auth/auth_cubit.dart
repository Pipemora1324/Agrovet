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

/// La cuenta existe pero falta escribir el código que llegó al correo.
class AwaitingVerification extends AuthState {
  const AwaitingVerification({
    required this.email,
    required this.resendAvailableAt,
    this.busy = false,
    this.message,
    this.info,
  });

  final String email;

  /// Desde cuándo se puede pedir otro código (el servidor exige una espera entre envíos).
  final DateTime resendAvailableAt;
  final bool busy;

  /// Error para mostrar (código incorrecto, sin conexión…).
  final String? message;

  /// Aviso neutro (por ejemplo, "Le enviamos un código nuevo").
  final String? info;

  AwaitingVerification copyWith({
    DateTime? resendAvailableAt,
    bool? busy,
    String? message,
    String? info,
  }) =>
      AwaitingVerification(
        email: email,
        resendAvailableAt: resendAvailableAt ?? this.resendAvailableAt,
        busy: busy ?? this.busy,
        message: message,
        info: info,
      );

  @override
  List<Object?> get props => [email, resendAvailableAt, busy, message, info];
}

class Authenticated extends AuthState {
  const Authenticated(this.session);

  final Session session;

  @override
  List<Object?> get props => [session];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required this.store,
    required this.api,
    this.allowDemo = kDebugMode,
    DateTime Function()? clock,
  })  : _now = clock ?? DateTime.now,
        super(const AuthChecking());

  final SecureStore store;
  final AuthApi api;
  final DateTime Function() _now;

  /// La entrada con datos de demostración solo existe en compilaciones debug.
  final bool allowDemo;

  /// Espera entre envíos de código; debe coincidir con la del servidor.
  static const resendCooldown = Duration(seconds: 60);

  /// Si ya hubo un ingreso, la sesión está guardada y la app abre sin necesitar conexión.
  Future<void> restore() async {
    final session = await store.readSession();
    emit(session == null ? const Unauthenticated() : Authenticated(session));
  }

  Future<void> login(String email, String password) async {
    emit(const Unauthenticated(busy: true));
    try {
      await _open(await api.login(email, password));
    } on ApiException catch (e) {
      if (e.isEmailNotVerified) {
        // El servidor envía un código si no había uno vigente; se puede pedir otro de inmediato
        emit(AwaitingVerification(email: email.trim(), resendAvailableAt: _now(), info: e.message));
      } else {
        emit(Unauthenticated(message: e.message));
      }
    }
  }

  Future<void> register(String name, String email, String password, {required bool acceptedPrivacy}) async {
    emit(const Unauthenticated(busy: true));
    try {
      await api.register(name, email, password, acceptedPrivacy: acceptedPrivacy);
      // La pantalla ya dice a qué correo se envió: no hace falta otro aviso
      emit(AwaitingVerification(email: email.trim(), resendAvailableAt: _now().add(resendCooldown)));
    } on ApiException catch (e) {
      emit(Unauthenticated(message: e.message));
    }
  }

  Future<void> verify(String code) async {
    final current = state;
    if (current is! AwaitingVerification || current.busy) return;
    emit(current.copyWith(busy: true));
    try {
      await _open(await api.verifyEmail(current.email, code));
    } on ApiException catch (e) {
      emit(current.copyWith(busy: false, message: e.message));
    }
  }

  Future<void> resendCode() async {
    final current = state;
    if (current is! AwaitingVerification || current.busy) return;
    if (_now().isBefore(current.resendAvailableAt)) return;
    emit(current.copyWith(busy: true));
    try {
      await api.resendCode(current.email);
      emit(current.copyWith(
        busy: false,
        resendAvailableAt: _now().add(resendCooldown),
        info: 'Le enviamos un código nuevo. El anterior ya no sirve.',
      ));
    } on ApiException catch (e) {
      emit(current.copyWith(
        busy: false,
        // Si el servidor pide esperar, la cuenta regresiva usa su tiempo
        resendAvailableAt: e.retryAfter == null ? null : _now().add(e.retryAfter!),
        message: e.message,
      ));
    }
  }

  /// Vuelve al ingreso (por ejemplo, para corregir el correo).
  void cancelVerification() => emit(const Unauthenticated());

  /// Sesión abierta desde otra pantalla (por ejemplo, al terminar de cambiar la contraseña).
  Future<void> openSession(Session session) => _open(session);

  /// Guarda el perfil o los tokens nuevos de la sesión actual (mismo usuario).
  Future<void> updateSession(Session session) async {
    final current = state;
    if (current is! Authenticated || current.session.userId != session.userId) return;
    await _open(session);
  }

  /// La cuenta se eliminó en el servidor (y sus datos locales ya se borraron).
  Future<void> accountDeleted() async {
    await store.clearSession();
    emit(const Unauthenticated(message: 'Su cuenta y todos sus datos fueron eliminados.'));
  }

  Future<void> _open(Session session) async {
    await store.saveSession(session);
    emit(Authenticated(session));
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
