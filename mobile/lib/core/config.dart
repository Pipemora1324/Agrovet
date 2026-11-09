import 'package:flutter/foundation.dart';

/// Configuración de compilación.
///
/// La dirección del servidor sale **solo** de `--dart-define=API_BASE_URL=...`; no hay una dirección
/// escrita en el código. En release debe ser HTTPS. HTTP sin cifrar solo se acepta en debug y solo
/// hacia el equipo de desarrollo (10.0.2.2 desde el emulador, localhost con `adb reverse`), igual que
/// en android/app/src/debug/res/xml/network_security_config.xml.
class AppConfig {
  AppConfig._();

  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Triaje visual de la ubre con la CNN. APAGADO por defecto: el modelo se entrenó con un dataset
  /// público cuyas etiquetas no confirmó un veterinario (ver ml/README.md). Solo se enciende
  /// compilando con `--dart-define=UDDER_TRIAGE=true`, y aun así el resultado es orientativo.
  static const udderTriageEnabled = bool.fromEnvironment('UDDER_TRIAGE');

  /// Equipos de desarrollo a los que se permite HTTP en debug.
  static const developmentHosts = {'10.0.2.2', 'localhost', '127.0.0.1'};

  /// Por qué la dirección no sirve, o null si está bien.
  static String? get problem => problemFor(apiBaseUrl, release: kReleaseMode);

  static String? problemFor(String url, {required bool release}) {
    if (url.isEmpty) {
      return 'Falta la dirección del servidor. Compile la app con '
          '--dart-define=API_BASE_URL=https://su-servidor';
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return 'La dirección del servidor no es válida: $url';
    if (uri.scheme == 'https') return null;
    if (uri.scheme == 'http' && !release && developmentHosts.contains(uri.host)) return null;
    return release
        ? 'En la versión publicada el servidor debe usar HTTPS: $url'
        : 'HTTP sin cifrar solo se permite hacia el equipo de desarrollo (10.0.2.2 o localhost): $url';
  }
}
