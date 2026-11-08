import 'package:dio/dio.dart';

import '../../domain/session.dart';
import 'api_client.dart';

/// Cuenta y sesión. Registro, verificación y recuperación necesitan internet; una vez abierta, la
/// sesión queda guardada y la app funciona sin conexión.
class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  Future<Session> login(String email, String password) =>
      _session('/api/auth/login', {'email': email.trim(), 'password': password});

  /// Crea la cuenta sin verificar; el servidor envía un código al correo.
  Future<void> register(String name, String email, String password) =>
      _post('/api/auth/register', {'name': name.trim(), 'email': email.trim(), 'password': password});

  /// El código correcto verifica el correo y abre la sesión.
  Future<Session> verifyEmail(String email, String code) =>
      _session('/api/auth/verify-email', {'email': email.trim(), 'code': code.trim()});

  Future<void> resendCode(String email) => _post('/api/auth/resend-code', {'email': email.trim()});

  Future<void> forgotPassword(String email) => _post('/api/auth/password/forgot', {'email': email.trim()});

  Future<void> resetPassword(String email, String code, String newPassword) => _post(
        '/api/auth/password/reset',
        {'email': email.trim(), 'code': code.trim(), 'newPassword': newPassword},
      );

  /// Revoca la sesión en el servidor. Si no hay conexión no importa: los tokens se borran igual.
  Future<void> logout(String refreshToken) async {
    try {
      await _client.dio.post<void>('/api/auth/logout', data: {'refreshToken': refreshToken});
    } on DioException {
      // Sin conexión: el refresh token expira solo
    }
  }

  Future<void> _post(String path, Map<String, String> body) async {
    try {
      await _client.dio.post<void>(path, data: body);
    } catch (e) {
      throw ApiClient.describe(e);
    }
  }

  Future<Session> _session(String path, Map<String, String> body) async {
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
