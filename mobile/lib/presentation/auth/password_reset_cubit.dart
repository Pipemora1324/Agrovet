import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/remote/api_client.dart';
import '../../data/remote/auth_api.dart';
import '../../domain/session.dart';
import 'auth_cubit.dart';

enum PasswordResetStep { email, code, done }

class PasswordResetState extends Equatable {
  const PasswordResetState({
    this.step = PasswordResetStep.email,
    this.email = '',
    this.busy = false,
    this.message,
    this.info,
    this.resendAvailableAt,
    this.session,
  });

  final PasswordResetStep step;
  final String email;
  final bool busy;
  final String? message;
  final String? info;
  final DateTime? resendAvailableAt;

  /// Sesión abierta con la contraseña nueva (paso done).
  final Session? session;

  PasswordResetState copyWith({
    PasswordResetStep? step,
    String? email,
    bool? busy,
    String? message,
    String? info,
    DateTime? resendAvailableAt,
    Session? session,
  }) =>
      PasswordResetState(
        step: step ?? this.step,
        email: email ?? this.email,
        busy: busy ?? this.busy,
        message: message,
        info: info,
        resendAvailableAt: resendAvailableAt ?? this.resendAvailableAt,
        session: session ?? this.session,
      );

  @override
  List<Object?> get props => [step, email, busy, message, info, resendAvailableAt, session];
}

/// "Olvidé mi contraseña": 1) pedir el código al correo, 2) escribirlo con la contraseña nueva.
/// Al terminar se inicia sesión con la contraseña nueva.
class PasswordResetCubit extends Cubit<PasswordResetState> {
  PasswordResetCubit(this._api, {String initialEmail = '', DateTime Function()? clock})
      : _now = clock ?? DateTime.now,
        super(PasswordResetState(email: initialEmail.trim()));

  final AuthApi _api;
  final DateTime Function() _now;

  Future<void> requestCode(String email) async {
    emit(state.copyWith(email: email.trim(), busy: true));
    try {
      await _api.forgotPassword(email);
      emit(state.copyWith(
        step: PasswordResetStep.code,
        busy: false,
        resendAvailableAt: _now().add(AuthCubit.resendCooldown),
        info: 'Si el correo está registrado, le llegará un código de 6 números.',
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        busy: false,
        message: e.message,
        resendAvailableAt: e.retryAfter == null ? null : _now().add(e.retryAfter!),
      ));
    }
  }

  Future<void> resend() => requestCode(state.email);

  Future<void> reset(String code, String newPassword) async {
    emit(state.copyWith(busy: true));
    try {
      await _api.resetPassword(state.email, code, newPassword);
      final session = await _api.login(state.email, newPassword);
      emit(state.copyWith(step: PasswordResetStep.done, busy: false, session: session));
    } on ApiException catch (e) {
      emit(state.copyWith(busy: false, message: e.message));
    }
  }

  /// Volver a escribir el correo.
  void changeEmail() => emit(PasswordResetState(email: state.email));
}
