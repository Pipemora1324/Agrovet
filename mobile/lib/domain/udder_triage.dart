/// Configuración del modelo de triaje visual de la ubre (assets/model/udder_cnn_config.json).
class UdderModelConfig {
  const UdderModelConfig({
    required this.modelFile,
    required this.inputSize,
    required this.threshold,
    required this.enabledByDefault,
    required this.disclaimer,
  });

  factory UdderModelConfig.fromJson(Map<String, dynamic> json) => UdderModelConfig(
        modelFile: json['modelFile'] as String,
        inputSize: json['inputSize'] as int,
        threshold: (json['threshold'] as num).toDouble(),
        enabledByDefault: json['enabledByDefault'] as bool,
        disclaimer: json['disclaimer'] as String,
      );

  final String modelFile;
  final int inputSize;
  final double threshold;
  final bool enabledByDefault;
  final String disclaimer;
}

/// Lectura de la foto: nunca es un diagnóstico.
class UdderTriageResult {
  const UdderTriageResult(this.probability, this.threshold);

  final double probability;
  final double threshold;

  bool get showsSigns => probability >= threshold;

  String get headline => showsSigns
      ? 'La foto se parece a ubres con signos de mastitis'
      : 'La foto no se parece a ubres con signos de mastitis';

  static const disclaimer = 'Resultado orientativo, no es diagnóstico. Haga la prueba de CMT o consulte '
      'al veterinario si nota la ubre caliente, dura o la leche con grumos.';
}
