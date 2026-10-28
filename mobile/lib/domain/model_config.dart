import 'entities.dart';

/// Lectura de assets/model/model_config.json, generado por ml/src/export_tflite.py.
class ModelConfig {
  const ModelConfig({
    required this.modelFile,
    required this.modelVersion,
    required this.features,
    required this.windowDays,
    required this.baseDays,
    required this.minValidDays,
    required this.validRanges,
    required this.temperatureScale,
    required this.milkScale,
    required this.feedScale,
    required this.threshold,
    required this.yellowMin,
  });

  factory ModelConfig.fromJson(Map<String, dynamic> json) {
    final pre = json['preprocessing'] as Map<String, dynamic>;
    final ranges = (pre['valid_ranges'] as Map<String, dynamic>).map((name, bounds) {
      final pair = bounds as List;
      return MapEntry(name, (min: (pair[0] as num).toDouble(), max: (pair[1] as num).toDouble()));
    });
    final features = List<String>.from((json['input'] as Map<String, dynamic>)['features'] as List);
    final lights = json['traffic_light'] as Map<String, dynamic>;
    return ModelConfig(
      modelFile: json['model_file'] as String,
      modelVersion: json['model_version'] as String,
      features: features,
      windowDays: pre['window_days'] as int,
      baseDays: pre['base_days'] as int,
      minValidDays: pre['min_valid_days'] as int,
      validRanges: {for (final name in features) name: ranges[name]!},
      temperatureScale: ((pre['temperature_c'] as Map)['scale'] as num).toDouble(),
      milkScale: ((pre['milk_l'] as Map)['scale'] as num).toDouble(),
      feedScale: ((pre['feed_kg'] as Map)['scale'] as num).toDouble(),
      threshold: (json['threshold'] as num).toDouble(),
      yellowMin: ((lights['yellow'] as Map)['min'] as num).toDouble(),
    );
  }

  final String modelFile;
  final String modelVersion;

  /// Orden de las variables en la entrada: temperatura, leche, alimento.
  final List<String> features;
  final int windowDays;
  final int baseDays;
  final int minValidDays;
  final Map<String, ({double min, double max})> validRanges;
  final double temperatureScale;
  final double milkScale;
  final double feedScale;
  final double threshold;
  final double yellowMin;

  /// Verde < mitad del umbral; amarillo hasta el umbral; rojo desde el umbral.
  RiskLevel riskLevelFor(double probability) {
    if (probability >= threshold) return RiskLevel.red;
    if (probability >= yellowMin) return RiskLevel.yellow;
    return RiskLevel.green;
  }
}
