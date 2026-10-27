/// Rangos de captura con mensajes claros. Son más amplios que los "válidos" del modelo: lo que
/// cae fuera de estos rangos casi seguro es un error de digitación y no se deja guardar.
class Validators {
  static const temperature = (min: 35.0, max: 42.0);
  static const milk = (min: 0.0, max: 45.0);
  static const feed = (min: 0.0, max: 35.0);

  static double? parseNumber(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    return double.tryParse(text.trim().replaceAll(',', '.'));
  }

  static String? measurement(String? text, ({double min, double max}) range, String unit, String label) {
    if (text == null || text.trim().isEmpty) return null; // se permite dejar vacío
    final value = parseNumber(text);
    if (value == null) return 'Escriba solo números, por ejemplo 38,6';
    if (value < range.min || value > range.max) {
      return '$label debe estar entre ${_fmt(range.min)} y ${_fmt(range.max)} $unit';
    }
    return null;
  }

  static String? temperatureC(String? text) => measurement(text, temperature, '°C', 'La temperatura');
  static String? milkL(String? text) => measurement(text, milk, 'L', 'La leche');
  static String? feedKg(String? text) => measurement(text, feed, 'kg', 'El alimento');

  static String? requiredText(String? text, String message) =>
      text == null || text.trim().isEmpty ? message : null;

  static String? email(String? text) {
    if (text == null || text.trim().isEmpty) return 'Escriba su correo';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text.trim()) ? null : 'El correo no es válido';
  }

  static String? password(String? text) {
    if (text == null || text.length < 8) return 'La contraseña debe tener al menos 8 caracteres';
    if (text.length > 72) return 'La contraseña es demasiado larga';
    return null;
  }

  static String _fmt(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString().replaceAll('.', ',');
}
