import 'model_config.dart';

/// Abstracción del modelo para poder probar la lógica sin cargar TFLite.
abstract interface class RiskPredictor {
  ModelConfig get config;

  /// Probabilidad de síntomas clínicos en 1 a 5 días para una ventana ya normalizada.
  double predict(List<List<double>> normalizedWindow);
}
