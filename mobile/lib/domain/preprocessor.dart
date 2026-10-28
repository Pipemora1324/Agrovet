import 'model_config.dart';

/// Réplica exacta de ml/src/preprocess.py. Cualquier cambio debe hacerse en ambos lados;
/// la prueba con test_vectors.json lo verifica.
///
/// 1. Un valor vacío o fuera de rango cuenta como faltante.
/// 2. Si una variable tiene menos de minValidDays valores válidos, la ventana no se usa.
/// 3. Los faltantes toman el último valor válido anterior; al comienzo, el primero válido.
/// 4. Base = media de los primeros baseDays días.
/// 5. Temperatura: (t - base) / escala. Leche y alimento: (x / base - 1) / escala.
class Preprocessor {
  const Preprocessor(this.config);

  final ModelConfig config;

  /// Ventana limpia, o null si no hay datos suficientes. raw: windowDays filas x 3 columnas.
  List<List<double>>? clean(List<List<double?>> raw) {
    final days = config.windowDays;
    if (raw.length != days || raw.any((row) => row.length != config.features.length)) {
      throw ArgumentError('Se esperaba una ventana de $days x ${config.features.length}');
    }
    final columns = <List<double>>[];
    for (var col = 0; col < config.features.length; col++) {
      final range = config.validRanges[config.features[col]]!;
      final valid = [
        for (final row in raw)
          row[col] != null && !row[col]!.isNaN && row[col]! >= range.min && row[col]! <= range.max,
      ];
      if (valid.where((v) => v).length < config.minValidDays) return null;

      var last = raw[valid.indexOf(true)][col]!;
      final values = <double>[];
      for (var day = 0; day < days; day++) {
        if (valid[day]) last = raw[day][col]!;
        values.add(last);
      }
      columns.add(values);
    }
    return [
      for (var day = 0; day < days; day++) [for (final column in columns) column[day]],
    ];
  }

  List<List<double>> normalize(List<List<double>> clean) {
    final base = List<double>.filled(clean.first.length, 0);
    for (var day = 0; day < config.baseDays; day++) {
      for (var col = 0; col < base.length; col++) {
        base[col] += clean[day][col];
      }
    }
    for (var col = 0; col < base.length; col++) {
      base[col] /= config.baseDays;
    }
    return [
      for (final row in clean)
        [
          (row[0] - base[0]) / config.temperatureScale,
          (row[1] / base[1] - 1.0) / config.milkScale,
          (row[2] / base[2] - 1.0) / config.feedScale,
        ],
    ];
  }

  List<List<double>>? preprocess(List<List<double?>> raw) {
    final cleaned = clean(raw);
    return cleaned == null ? null : normalize(cleaned);
  }
}
