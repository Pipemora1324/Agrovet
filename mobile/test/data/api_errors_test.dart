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
