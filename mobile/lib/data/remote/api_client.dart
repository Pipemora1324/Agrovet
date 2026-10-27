import 'dart:async';

import 'package:dio/dio.dart';

import '../../domain/session.dart';
import '../security/secure_store.dart';

/// Error de la API con un mensaje listo para mostrar al ganadero.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Cliente HTTP con el token de acceso y renovación automática.
///
/// Si una llamada responde 401, renueva la sesión una sola vez (aunque fallen varias llamadas a
/// la vez, porque el refresh token rota y solo sirve una vez) y repite la llamada.
class ApiClient {
  ApiClient({required String baseUrl, required this.store, Dio? dio, Dio? refreshDio})
      : dio = dio ?? Dio(_options(baseUrl)),
        _refreshDio = refreshDio ?? Dio(_options(baseUrl)) {
    this.dio.interceptors.add(InterceptorsWrapper(onRequest: _attachToken, onError: _onError));
  }

  final Dio dio;
  final Dio _refreshDio;
  final SecureStore store;
  Future<Session?>? _refreshing;

  /// Se llama cuando el servidor rechaza el refresh token: hay que volver a iniciar sesión.
  void Function()? onSessionExpired;

  static const _publicPaths = ['/api/auth/login', '/api/auth/register', '/api/auth/refresh'];

  static BaseOptions _options(String baseUrl) => BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
      );

  Future<void> _attachToken(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_publicPaths.contains(options.path)) {
      final session = await store.readSession();
      if (session?.accessToken != null) {
        options.headers['Authorization'] = 'Bearer ${session!.accessToken}';
      }
    }
    handler.next(options);
  }

  Future<void> _onError(DioException error, ErrorInterceptorHandler handler) async {
    final request = error.requestOptions;
    final retried = request.extra['retried'] == true;
    if (error.response?.statusCode != 401 || retried || _publicPaths.contains(request.path)) {
      return handler.next(error);
    }
    final session = await _refreshSession();
    if (session == null) return handler.next(error);
    request.extra['retried'] = true;
    request.headers['Authorization'] = 'Bearer ${session.accessToken}';
    try {
      handler.resolve(await dio.fetch(request));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<Session?> _refreshSession() {
    return _refreshing ??= () async {
      try {
        final session = await store.readSession();
        if (session?.refreshToken == null) return null;
        final response = await _refreshDio.post<Map<String, dynamic>>('/api/auth/refresh',
            data: {'refreshToken': session!.refreshToken});
        final data = response.data!;
        final renewed = session.withTokens(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
        );
        await store.saveSession(renewed);
        return renewed;
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) onSessionExpired?.call();
        return null;
      } finally {
        _refreshing = null;
      }
    }();
  }

  /// Traduce un error de red o del servidor a un mensaje en español.
  static ApiException describe(Object error) {
    if (error is ApiException) return error;
    if (error is! DioException) return const ApiException('Ocurrió un error inesperado.');
    final response = error.response;
    if (response == null) {
      return const ApiException('No hay conexión con el servidor. Revise su internet e intente de nuevo.');
    }
    final data = response.data;
    if (data is Map && data['errors'] is Map && (data['errors'] as Map).isNotEmpty) {
      return ApiException((data['errors'] as Map).values.first.toString(), statusCode: response.statusCode);
    }
    if (data is Map && data['detail'] is String) {
      return ApiException(data['detail'] as String, statusCode: response.statusCode);
    }
    return ApiException('El servidor respondió con un error (${response.statusCode}).',
        statusCode: response.statusCode);
  }
}
