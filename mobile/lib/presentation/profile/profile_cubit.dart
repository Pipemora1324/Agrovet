import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/local/local_data_wiper.dart';
import '../../data/remote/api_client.dart';
import '../../data/remote/profile_api.dart';
import '../../domain/privacy_notice.dart';
import '../../domain/session.dart';
import '../auth/auth_cubit.dart';

class ProfileState extends Equatable {
  const ProfileState({this.busy = false, this.message, this.error});

  final bool busy;

  /// Aviso de éxito ("Cambios guardados").
  final String? message;
  final String? error;

  @override
  List<Object?> get props => [busy, message, error];
}

/// Acciones del perfil. Los cambios se hacen en el servidor (necesitan internet); la copia local
/// del perfil se actualiza para verlo sin conexión.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({required this.api, required this.auth, required this.wiper}) : super(const ProfileState());

  final ProfileApi api;
  final AuthCubit auth;
  final LocalDataWiper wiper;

  Session? get _session => switch (auth.state) {
        Authenticated(:final session) => session,
        _ => null,
      };

  /// Trae el perfil del servidor si hay conexión; si no, se queda con la copia local sin avisar.
  Future<void> refresh() async {
    final session = _session;
    if (session == null || session.isDemo) return;
    try {
      await auth.updateSession(session.withProfile(await api.fetch()));
    } on ApiException {
      // Sin conexión: se muestra lo guardado
    }
  }

  Future<bool> save({required String name, String? farmName, String? municipality, String? phone}) =>
      _run('Cambios guardados.', () async {
        final profile = await api.update(name: name, farmName: farmName, municipality: municipality, phone: phone);
        await auth.updateSession(_session!.withProfile(profile));
      });

  Future<bool> acceptPrivacy() => _run('Gracias. Quedó registrada su autorización.', () async {
        final profile = await api.acceptPrivacy(PrivacyNotice.version);
        await auth.updateSession(_session!.withProfile(profile));
      });

  Future<bool> changePassword(String current, String newPassword) =>
      _run('Contraseña cambiada. Se cerraron las sesiones en otros celulares.', () async {
        final renewed = await api.changePassword(current, newPassword);
        await auth.updateSession(_session!.withTokens(
          accessToken: renewed.accessToken!,
          refreshToken: renewed.refreshToken!,
        ));
      });

  /// Elimina la cuenta en el servidor y después borra todo de este celular. Primero se sale de la
  /// sesión (las pantallas dejan de leer la base) y luego se borran la base y sus claves.
  Future<bool> deleteAccount(String password) async {
    final ok = await _run(null, () => api.deleteAccount(password));
    if (!ok) return false;
    await auth.accountDeleted();
    await wiper.wipe();
    return true;
  }

  void clearMessages() => emit(ProfileState(busy: state.busy));

  Future<bool> _run(String? success, Future<void> Function() action) async {
    if (_session == null || _session!.isDemo) {
      emit(const ProfileState(error: 'La sesión de demostración no tiene cuenta en el servidor.'));
      return false;
    }
    emit(const ProfileState(busy: true));
    try {
      await action();
      emit(ProfileState(message: success));
      return true;
    } on ApiException catch (e) {
      emit(ProfileState(error: e.message));
      return false;
    }
  }
}
