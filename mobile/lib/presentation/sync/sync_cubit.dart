import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/sync/sync_service.dart';

class SyncState extends Equatable {
  const SyncState({
    this.pending = 0,
    this.syncing = false,
    this.lastSyncAt,
    this.lastError,
    this.rejected = const [],
    this.message,
    this.enabled = true,
  });

  final int pending;
  final bool syncing;

  /// Última vez que el servidor confirmó cambios.
  final DateTime? lastSyncAt;

  /// Por qué falló el último intento; se borra cuando uno sale bien.
  final String? lastError;

  /// Lo que el servidor no aceptó, con su motivo.
  final List<SyncIssue> rejected;

  /// Resultado del último intento pedido por el ganadero, para mostrarlo una vez.
  final String? message;

  /// En la sesión de demostración no se sincroniza.
  final bool enabled;

  bool get hasProblems => lastError != null || rejected.isNotEmpty;

  SyncState copyWith({
    int? pending,
    bool? syncing,
    DateTime? lastSyncAt,
    String? lastError,
    bool clearError = false,
    List<SyncIssue>? rejected,
    String? message,
    bool clearMessage = false,
  }) =>
      SyncState(
        pending: pending ?? this.pending,
        syncing: syncing ?? this.syncing,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        lastError: clearError ? null : lastError ?? this.lastError,
        rejected: rejected ?? this.rejected,
        message: clearMessage ? null : message ?? this.message,
        enabled: enabled,
      );

  @override
  List<Object?> get props => [pending, syncing, lastSyncAt, lastError, rejected, message, enabled];
}

/// Sincroniza al abrir la sesión, al volver la app al frente, al recuperar la conexión y cuando el
/// ganadero lo pide. WorkManager se encarga de hacerlo con la app cerrada.
class SyncCubit extends Cubit<SyncState> {
  SyncCubit(
    SyncService service, {
    required Stream<bool> connectivity,
    Stream<void>? appResumed,
    Future<DateTime?> Function()? loadLastSync,
    this._saveLastSync,
    DateTime Function()? clock,
  })  : _service = service,
        _now = clock ?? DateTime.now,
        super(const SyncState()) {
    _subscriptions.addAll([
      service.watchPendingCount().listen((n) => emit(state.copyWith(pending: n))),
      service.watchRejected().listen((issues) => emit(state.copyWith(rejected: issues))),
      connectivity.distinct().listen((online) {
        if (online) _syncIfPending();
      }),
      if (appResumed != null) appResumed.listen((_) => _syncIfPending()),
    ]);
    loadLastSync?.call().then((at) {
      if (at != null && !isClosed && state.lastSyncAt == null) emit(state.copyWith(lastSyncAt: at));
    });
  }

  /// Para la sesión de demostración: sin servicio ni red.
  SyncCubit.disabled()
      : _service = null,
        _saveLastSync = null,
        _now = DateTime.now,
        super(const SyncState(enabled: false));

  final SyncService? _service;
  final Future<void> Function(DateTime at)? _saveLastSync;
  final DateTime Function() _now;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  void _syncIfPending() {
    if (state.pending > 0) syncNow(silent: true);
  }

  Future<void> syncNow({bool silent = false}) async {
    final service = _service;
    if (service == null || state.syncing) return;
    emit(state.copyWith(syncing: true, clearMessage: true));
    final report = await service.syncNow();
    if (isClosed) return;
    if (!report.ok) {
      final error = report.error!;
      emit(state.copyWith(
        syncing: false,
        lastError: error,
        message: silent ? null : '$error Sus datos siguen guardados en el celular.',
        clearMessage: silent,
      ));
      return;
    }
    // Solo cuenta como sincronización si el servidor confirmó algo
    final at = report.sent > 0 ? _now() : null;
    if (at != null) await _saveLastSync?.call(at);
    if (isClosed) return;
    final String? message;
    if (report.rejected > 0) {
      message = '${report.rejected} cambio(s) fueron rechazados por el servidor.';
    } else {
      message = silent || report.sent == 0 ? null : 'Datos respaldados en el servidor.';
    }
    emit(state.copyWith(
      syncing: false,
      lastSyncAt: at,
      clearError: true,
      message: message,
      clearMessage: message == null,
    ));
  }

  void messageShown() => emit(state.copyWith(clearMessage: true));

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    return super.close();
  }
}
