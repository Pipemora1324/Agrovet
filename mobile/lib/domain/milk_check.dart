/// Configuración del clasificador experimental de leche (assets/model/milk_cnn_config.json).
class MilkModelConfig {
  const MilkModelConfig({
    required this.modelFile,
    required this.inputSize,
    required this.threshold,
    required this.onlyDemoBuild,
    required this.disclaimer,
  });

  factory MilkModelConfig.fromJson(Map<String, dynamic> json) => MilkModelConfig(
        modelFile: json['modelFile'] as String,
        inputSize: json['inputSize'] as int,
        threshold: (json['threshold'] as num).toDouble(),
        onlyDemoBuild: json['onlyDemoBuild'] as bool,
        disclaimer: json['disclaimer'] as String,
      );

  final String modelFile;
  final int inputSize;
  final double threshold;
  final bool onlyDemoBuild;
  final String disclaimer;
}

/// Zona de la foto que se analiza, en píxeles enteros: [left, right) × [top, bottom).
class CropBox {
  const CropBox(this.left, this.top, this.right, this.bottom);

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => right - left;
  int get height => bottom - top;

  /// La zona dentro de una imagen de [imageWidth] × [imageHeight], con al menos un píxel.
  CropBox clampTo(int imageWidth, int imageHeight) {
    final l = left.clamp(0, imageWidth - 1);
    final t = top.clamp(0, imageHeight - 1);
    return CropBox(l, t, right.clamp(l + 1, imageWidth), bottom.clamp(t + 1, imageHeight));
  }

  @override
  bool operator ==(Object other) =>
      other is CropBox && other.left == left && other.top == top && other.right == right && other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'CropBox($left, $top, $right, $bottom)';
}

/// Lectura del pozo de leche: experimental, nunca es un diagnóstico.
class MilkCheckResult {
  const MilkCheckResult(this.probability, this.threshold);

  final double probability;
  final double threshold;

  bool get abnormal => probability >= threshold;

  String get label => abnormal ? 'Anormal' : 'Normal';

  /// Probabilidad de leche de aspecto anormal, en porcentaje entero.
  int get percent => (probability * 100).round();

  /// Texto fijo de la pantalla (también en milk_cnn_config.json).
  static const disclaimer =
      'Experimental. No es diagnóstico. Solo validado con un conjunto de datos; con fotos nuevas puede fallar.';

  /// Lo que el modelo no puede ver.
  static const limits = 'El aspecto de la leche solo cambia en la mastitis clínica; la subclínica no se ve '
      'en una foto. Ante cualquier duda, haga la prueba de CMT o consulte al veterinario.';
}
