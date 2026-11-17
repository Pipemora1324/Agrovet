import 'dart:async';

import 'package:agrovet/data/remote/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mensajes que ve el ganadero cuando falla la red o el servidor (prueba en emulador, 2026-11-09).
void main() {
  final request = RequestOptions(path: '/api/assistant');

  test('sin respuesta no culpa solo a la señal y dice que los datos siguen guardados', () {
    final error = ApiClient.describe(DioException(requestOptions: request, type: DioExceptionType.connectionError));
    expect(error.message, contains('servidor de AgroVet'));
    expect(error.message, contains('Puede ser la señal o que el servidor no esté disponible'));
    expect(error.message, contains('siguen guardados en el celular'));
  });

  test('un error del servidor sin detalle no muestra el código técnico', () {
    final error = ApiClient.describe(DioException(
      requestOptions: request,
      response: Response(requestOptions: request, statusCode: 500, data: 'x'),
    ));
    expect(error.message, isNot(contains('500')));
    expect(error.statusCode, 500);
  });

  test('sin respuesta o con tiempo agotado la llamada cuenta como no llegada al servidor', () {
    for (final type in [
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
    ]) {
      final error = ApiClient.describe(DioException(requestOptions: request, type: type));
      expect(error.unreachable, isTrue, reason: '$type');
      expect(error.isOffline, isTrue, reason: '$type');
    }
  });

  test('tiempo agotado: explica que el servidor puede estar despertando', () {
    final error = ApiClient.describe(DioException(requestOptions: request, type: DioExceptionType.receiveTimeout));
    expect(error, same(ApiClient.timedOut));
    expect(error.message, contains('despertar'));
    expect(ApiClient.describe(TimeoutException('x')), same(ApiClient.timedOut));
  });

  test('un 502/503/504 del proxy (sin cuerpo de la API) no se muestra como fallo del servidor', () {
    for (final status in [502, 503, 504]) {
      final error = ApiClient.describe(DioException(
        requestOptions: request,
        response: Response(requestOptions: request, statusCode: status, data: '<html>Bad gateway</html>'),
      ));
      expect(error.unreachable, isTrue, reason: '$status');
      expect(error.message, contains('no está disponible en este momento'));
      expect(error.message, isNot(contains('tuvo un problema')));
    }
  });

  test('un 503 de la API con su detalle llegó al servidor y conserva el motivo', () {
    final error = ApiClient.describe(DioException(
      requestOptions: request,
      response: Response(
        requestOptions: request,
        statusCode: 503,
        data: {'detail': 'El asistente no está configurado en este servidor.'},
      ),
    ));
    expect(error.unreachable, isFalse);
    expect(error.message, 'El asistente no está configurado en este servidor.');
  });

  test('un 429 conserva el detalle del servidor y el tiempo de espera', () {
    final error = ApiClient.describe(DioException(
      requestOptions: request,
      response: Response(
        requestOptions: request,
        statusCode: 429,
        data: {'detail': 'Hizo muchas preguntas seguidas. Espere un momento.'},
        headers: Headers.fromMap({'retry-after': ['60']}),
      ),
    ));
    expect(error.message, 'Hizo muchas preguntas seguidas. Espere un momento.');
    expect(error.retryAfter, const Duration(seconds: 60));
  });
}
