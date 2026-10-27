/// Configuración de compilación.
///
/// La URL del backend se pasa con --dart-define=API_BASE_URL=... Por defecto apunta al backend del
/// docker-compose visto desde el emulador de Android (10.0.2.2 = el equipo). En release debe ser HTTPS:
/// el permiso para HTTP sin cifrar solo existe en las compilaciones debug.
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080');
}
