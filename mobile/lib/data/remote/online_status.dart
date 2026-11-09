import 'dart:async';

/// Estado de la conexión a internet, compartido por la sesión: recuerda el último valor y avisa los
/// cambios.
class OnlineStatus {
  OnlineStatus(Stream<bool> source, {bool initial = true}) : _online = initial {
    _subscription = source.listen((value) {
      _online = value;
      _changes.add(value);
    });
  }

  final _changes = StreamController<bool>.broadcast();
  late final StreamSubscription<bool> _subscription;
  bool _online;

  bool get online => _online;
  Stream<bool> get changes => _changes.stream;

  Future<void> dispose() async {
    await _subscription.cancel();
    await _changes.close();
  }
}
