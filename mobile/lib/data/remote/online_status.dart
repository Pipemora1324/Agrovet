import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Si el sistema tiene alguna red activa (wifi, datos o cable). No garantiza que el servidor responda,
/// pero sin red se sabe de inmediato que ninguna llamada va a salir.
Future<bool> deviceHasNetwork() async =>
    (await Connectivity().checkConnectivity()).any((r) => r != ConnectivityResult.none);

/// Estado de la conexión a internet, compartido por la sesión: recuerda el último valor y avisa los
/// cambios.
class OnlineStatus {
  OnlineStatus(Stream<bool> source, {bool initial = true, this._check}) : _online = initial {
    _subscription = source.listen((value) {
      _online = value;
      _changes.add(value);
    });
  }

  final _changes = StreamController<bool>.broadcast();
  late final StreamSubscription<bool> _subscription;
  bool _online;

  final Future<bool> Function()? _check;

  bool get online => _online;
  Stream<bool> get changes => _changes.stream;

  /// Pregunta al sistema en este momento (el aviso de cambios puede llegar con retraso). Sin una
  /// forma de preguntar (pruebas), usa el último valor conocido.
  Future<bool> checkNow() async {
    final check = _check;
    if (check == null) return _online;
    _online = await check();
    return _online;
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _changes.close();
  }
}
