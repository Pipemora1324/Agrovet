import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/sync/sync_service.dart';

class SyncState extends Equatable {
  const SyncState({this.pending = 0, this.syncing = false, this.message, this.enabled = true});

  final int pending;
  final bool syncing;

  /// Resultado del último intento, para mostrarlo una vez.
  final String? message;

  /// En la sesión de demostración no se sincroniza.
  final bool enabled;

  SyncState copyWith({int? pending, bool? syncing, String? message, bool clearMessage = false}) => SyncState(
        pending: pending ?? this.pending,
        syncing: syncing ?? this.syncing,
        message: clearMessage ? null : message ?? this.message,
        enabled: enabled,
      );

  @override
  List<Object?> get props => [pending, syncing, message, enabled];
}

/// Sincroniza al abrir la sesión, al recuperar la conexión y cuando el ganadero lo pide.
class SyncCubit extends Cubit<SyncState> {
  SyncCubit(SyncService service, {required Stream<bool> connectivity})
      : _service = service,
        super(const SyncState()) {
    _pendingSubscription = service.watchPendingCount().listen((n) => emit(state.copyWith(pending: n)));
    _connectivitySubscription = connectivity.distinct().listen((online) {
      if (online && state.pending > 0) syncNow(silent: true);
    });
  }

  /// Para la sesión de demostración: sin servicio ni red.
  SyncCubit.disabled()
      : _service = null,
        super(const SyncState(enabled: false));

  final SyncService? _service;
  StreamSubscription<int>? _pendingSubscription;
  StreamSubscription<bool>? _connectivitySubscription;

  Future<void> syncNow({bool silent = false}) async {
    final service = _service;
    if (service == null || state.syncing) return;
    emit(state.copyWith(syncing: true, clearMessage: true));
    final report = await service.syncNow();
    if (isClosed) return;
    final String? message;
    if (!report.ok) {
      message = silent ? null : '${report.error} Sus datos siguen guardados en el celular.';
    } else if (report.rejected > 0) {
      message = '${report.rejected} cambio(s) fueron rechazados por el servidor.';
    } else {
      message = silent || report.sent == 0 ? null : 'Datos respaldados en el servidor.';
    }
    emit(state.copyWith(syncing: false, message: message, clearMessage: message == null));
  }

  void messageShown() => emit(state.copyWith(clearMessage: true));

  @override
  Future<void> close() async {
    await _pendingSubscription?.cancel();
    await _connectivitySubscription?.cancel();
    return super.close();
  }
}
