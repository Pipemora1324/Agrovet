import 'package:dio/dio.dart';

import '../../domain/session.dart';
import 'api_client.dart';

class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  Future<Session> login(String email, String password) =>
      _authenticate('/api/auth/login', {'email': email.trim(), 'password': password});

  Future<Session> register(String name, String email, String password) =>
      _authenticate('/api/auth/register', {'name': name.trim(), 'email': email.trim(), 'password': password});

  /// Revoca la sesión en el servidor. Si no hay conexión no importa: los tokens se borran igual.
  Future<void> logout(String refreshToken) async {
    try {
      await _client.dio.post<void>('/api/auth/logout', data: {'refreshToken': refreshToken});
    } on DioException {
      // Sin conexión: el refresh token expira solo
    }
  }

  Future<Session> _authenticate(String path, Map<String, String> body) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(path, data: body);
      final data = response.data!;
      final user = data['user'] as Map<String, dynamic>;
      return Session(
        userId: user['id'] as String,
        name: user['name'] as String,
        email: user['email'] as String,
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
    } catch (e) {
      throw ApiClient.describe(e);
    }
  }
}
