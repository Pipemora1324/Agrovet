import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../data/ml/milk_model.dart';
import '../../data/photos/photo_capture.dart';
import '../../domain/milk_check.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/notice_box.dart';

typedef MilkEstimator = Future<MilkCheckResult> Function(Uint8List rgb);

/// Zona de la foto que se ve dentro del recuadro, en píxeles de la foto.
///
/// La foto se dibuja centrada y entera dentro de un cuadrado de lado [viewport] (como el relleno
/// negro del entrenamiento) y la persona la mueve y la acerca; [transform] es la transformación
/// de ese cuadrado.
CropBox cropBoxFor(Matrix4 transform, double viewport, int width, int height) {
  final visible = MatrixUtils.transformRect(Matrix4.inverted(transform), Rect.fromLTWH(0, 0, viewport, viewport));
  final scale = viewport / math.max(width, height);
  final dx = (viewport - width * scale) / 2;
  final dy = (viewport - height * scale) / 2;
  return CropBox(
    ((visible.left - dx) / scale).floor(),
    ((visible.top - dy) / scale).floor(),
    ((visible.right - dx) / scale).ceil(),
    ((visible.bottom - dy) / scale).ceil(),
  ).clampTo(width, height);
}

/// Pantalla experimental (solo en el APK de demostración): foto de un pozo de la paleta de
/// ordeño, normal o anormal según un modelo entrenado con un solo conjunto de datos público.
class MilkCheckScreen extends StatefulWidget {
  const MilkCheckScreen({super.key, this.estimator = estimateWithModel, this.decode = decodeRgba});

  final MilkEstimator estimator;
  final Future<DecodedImage> Function(Uint8List encoded) decode;

  static Future<MilkCheckResult> estimateWithModel(Uint8List rgb) async {
    final model = await MilkModel.load();
    try {
      return model.predict(rgb);
    } finally {
      model.close();
    }
  }

  @override
  State<MilkCheckScreen> createState() => _MilkCheckScreenState();
}

class _MilkCheckScreenState extends State<MilkCheckScreen> {
  static const inputSize = 160;

  Uint8List? _photo;
  DecodedImage? _decoded;
  MilkCheckResult? _result;
  String? _error;
  bool _busy = false;

  Future<void> _pick(PhotoSource source) async {
    final result = await context.read<PhotoCapture>().pick(source);
    if (!mounted) return;
    switch (result) {
      case Captured(:final bytes):
        setState(() {
          _busy = true;
          _error = null;
          _result = null;
        });
        try {
          final decoded = await widget.decode(bytes);
          setState(() {
            _photo = bytes;
            _decoded = decoded;
          });
        } on Exception {
          setState(() => _error = 'No se pudo abrir la foto. Pruebe con otra.');
          return;
        } finally {
          if (mounted) setState(() => _busy = false);
        }
        await _frame();
      case CaptureFailed(:final message):
        setState(() => _error = message);
      case CaptureCancelled():
        break;
    }
  }

  /// Abre la pantalla para encuadrar el pozo y analiza lo que quedó dentro del recuadro.
  Future<void> _frame() async {
    final photo = _photo;
    final decoded = _decoded;
    if (photo == null || decoded == null || !mounted) return;
    final box = await Navigator.push<CropBox>(
      context,
      MaterialPageRoute(builder: (_) => MilkCropScreen(photo: photo, width: decoded.width, height: decoded.height)),
    );
    if (box == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await widget.estimator(milkInput(decoded, box, inputSize));
      if (mounted) setState(() => _result = result);
    } on Exception {
      if (mounted) setState(() => _error = 'No se pudo analizar la foto.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      title: 'Leche (experimental)',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Disclaimer(),
                const SizedBox(height: 16),
                Text(
                  'Tome o elija una foto de la paleta de ordeño. Después acerque y mueva la foto hasta que '
                  'un solo pozo de leche llene el círculo amarillo.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _pick(PhotoSource.camera),
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Tomar foto'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _pick(PhotoSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Elegir de la galería'),
                    ),
                  ],
                ),
                if (_busy) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  NoticeBox.error(_error!),
                ],
                if (_result != null) ...[
                  const SizedBox(height: 16),
                  _ResultCard(result: _result!),
                ],
                if (_photo != null && !_busy) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _frame,
                    icon: const Icon(Icons.crop_free),
                    label: const Text('Analizar otro pozo de esta foto'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Encuadre del pozo: la foto entera centrada en un recuadro, que se acerca con dos dedos o con
/// los botones y se mueve con un dedo. Sin desplazamiento de la pantalla, para que el arrastre
/// mueva la foto. Devuelve la zona elegida.
class MilkCropScreen extends StatefulWidget {
  const MilkCropScreen({super.key, required this.photo, required this.width, required this.height});

  final Uint8List photo;
  final int width;
  final int height;

  static const maxScale = 12.0;
  static const zoomStep = 1.25;

  /// Parte del recuadro que ocupa el pozo en el entrenamiento: caja + 10 % por lado = 1 / 1,2.
  static const wellFraction = 1 / 1.2;

  @override
  State<MilkCropScreen> createState() => _MilkCropScreenState();
}

class _MilkCropScreenState extends State<MilkCropScreen> {
  final _transform = TransformationController();

  static const _border = 3.0;

  /// Lado interior del recuadro en la última construcción.
  double _viewport = 1;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  /// Acerca o aleja alrededor del centro del recuadro, para quien no usa el gesto de dos dedos.
  void _zoom(double factor) {
    final current = _transform.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(1.0, MilkCropScreen.maxScale);
    final step = target / current;
    if (step == 1.0) return;
    final center = _viewport / 2;
    final around = Matrix4.identity()
      ..translateByDouble(center, center, 0, 1)
      ..scaleByDouble(step, step, 1, 1)
      ..translateByDouble(-center, -center, 0, 1);
    _transform.value = around.multiplied(_transform.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      title: 'Encuadrar el pozo',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Acerque y mueva la foto hasta que un solo pozo llene el círculo amarillo. Si el pozo queda '
              'pequeño o se ven otros pozos, el resultado cambia mucho.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Lado interior del recuadro (sin el borde): es la zona que se analiza
                  _viewport = math.min(constraints.maxWidth, constraints.maxHeight) - 2 * _border;
                  return Center(
                    child: Container(
                      key: const Key('milk-crop-frame'),
                      width: _viewport + 2 * _border,
                      height: _viewport + 2 * _border,
                      decoration: BoxDecoration(
                        color: AppColors.trafficLightBody,
                        border: Border.all(color: AppColors.sun, width: _border),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRect(
                            child: InteractiveViewer(
                              transformationController: _transform,
                              maxScale: MilkCropScreen.maxScale,
                              child: SizedBox(
                                width: _viewport,
                                height: _viewport,
                                child: Image.memory(widget.photo, fit: BoxFit.contain, gaplessPlayback: true),
                              ),
                            ),
                          ),
                          // Guía: en el entrenamiento el pozo ocupa la caja y el recorte suma 10 % por lado
                          IgnorePointer(
                            child: Container(
                              key: const Key('milk-guide'),
                              width: _viewport * MilkCropScreen.wellFraction,
                              height: _viewport * MilkCropScreen.wellFraction,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.sun, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  tooltip: 'Alejar',
                  iconSize: AppSizes.icon,
                  onPressed: () => _zoom(1 / MilkCropScreen.zoomStep),
                  icon: const Icon(Icons.zoom_out),
                ),
                const SizedBox(width: 16),
                IconButton.outlined(
                  tooltip: 'Acercar',
                  iconSize: AppSizes.icon,
                  onPressed: () => _zoom(MilkCropScreen.zoomStep),
                  icon: const Icon(Icons.zoom_in),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                context,
                cropBoxFor(_transform.value, _viewport, widget.width, widget.height),
              ),
              icon: const Icon(Icons.science_outlined),
              label: const Text('Analizar el pozo del recuadro'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.highlightSurface,
          border: Border.all(color: AppColors.highlightBorder),
          borderRadius: AppRadius.field,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.warningText),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                MilkCheckResult.disclaimer,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.warningText),
              ),
            ),
          ],
        ),
      );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final MilkCheckResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = result.abnormal ? AppColors.riskRedText : AppColors.riskGreenText;
    return Card(
      key: const Key('milk-result'),
      color: result.abnormal ? AppColors.riskRedSurface : AppColors.riskGreenSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Lectura experimental del pozo', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(result.label, style: theme.textTheme.headlineSmall?.copyWith(color: color)),
            const SizedBox(height: 4),
            Text(
              'Probabilidad de leche de aspecto anormal: ${result.percent} %',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(MilkCheckResult.disclaimer, style: theme.textTheme.bodyMedium?.copyWith(color: color)),
            const SizedBox(height: 4),
            Text(MilkCheckResult.limits, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
