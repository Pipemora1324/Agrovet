import '../../domain/session.dart';
import 'api_client.dart';
import 'auth_api.dart';

/// Perfil de la cuenta. Todas las operaciones necesitan internet y la sesión abierta.
class ProfileApi {
  ProfileApi(this._client);

  final ApiClient _client;

  /// Perfil actual en el servidor (sin tokens).
  Future<Session> fetch() => _user(() => _client.dio.get<Map<String, dynamic>>('/api/auth/me'));

  Future<Session> update({
    required String name,
    String? farmName,
    String? municipality,
    String? phone,
  }) =>
      _user(() => _client.dio.put<Map<String, dynamic>>('/api/auth/me', data: {
            'name': name.trim(),
            'farmName': farmName?.trim() ?? '',
            'municipality': municipality?.trim() ?? '',
            'phone': phone?.trim() ?? '',
          }));

  Future<Session> acceptPrivacy(String version) => _user(() =>
      _client.dio.post<Map<String, dynamic>>('/api/auth/me/privacy', data: {'privacyPolicyVersion': version}));

  /// Cambia la contraseña; el servidor cierra las demás sesiones y devuelve tokens nuevos.
  Future<Session> changePassword(String currentPassword, String newPassword) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>('/api/auth/me/password',
          data: {'currentPassword': currentPassword, 'newPassword': newPassword});
      return sessionFrom(response.data!);
    } catch (e) {
      throw ApiClient.describe(e);
    }
  }

  /// Elimina la cuenta y todos sus datos en el servidor.
  Future<void> deleteAccount(String password) async {
    try {
      await _client.dio.delete<void>('/api/auth/me', data: {'password': password});
    } catch (e) {
      throw ApiClient.describe(e);
    }
  }

  Future<Session> _user(Future<dynamic> Function() call) async {
    try {
      final response = await call();
      return Session.fromUser(response.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.describe(e);
    }
  }
}
