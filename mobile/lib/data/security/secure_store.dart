import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/session.dart';

/// Tokens de sesión y claves de la base local en el almacenamiento seguro de Android (Keystore).
class SecureStore {
  SecureStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _sessionKey = 'session';

  Future<void> saveSession(Session session) =>
      _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));

  Future<Session?> readSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null) return null;
    try {
      return Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      await clearSession();
      return null;
    }
  }

  Future<void> clearSession() => _storage.delete(key: _sessionKey);

  /// Devuelve la clave de la base del usuario y la crea la primera vez.
  Future<String> databaseKeyFor(String userId) async {
    final name = 'db_key_$userId';
    final existing = await _storage.read(key: name);
    if (existing != null) return existing;
    final key = generateHexKey();
    await _storage.write(key: name, value: key);
    return key;
  }

  static String generateHexKey([Random? random]) {
    final rng = random ?? Random.secure();
    return List.generate(32, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}
