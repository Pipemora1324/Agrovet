import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/ml/udder_model.dart';
import '../../domain/udder_triage.dart';

typedef UdderEstimator = Future<UdderTriageResult> Function(File photo);

/// Lectura orientativa de la foto de la ubre con la CNN. Solo se muestra si la app se compiló con
/// el triaje encendido (AppConfig.udderTriageEnabled, apagado por defecto). Siempre dice que no es
/// un diagnóstico.
class UdderTriageCard extends StatefulWidget {
  const UdderTriageCard({super.key, required this.photo, this.estimator = estimateWithModel});

  final File photo;
  final UdderEstimator estimator;

  static Future<UdderTriageResult> estimateWithModel(File photo) async {
    final model = await UdderModel.load();
    try {
      final input = await udderInputFromEncoded(await photo.readAsBytes(), model.config.inputSize);
      return model.predict(input);
    } finally {
      model.close();
    }
  }

  @override
  State<UdderTriageCard> createState() => _UdderTriageCardState();
}

class _UdderTriageCardState extends State<UdderTriageCard> {
  late final Future<UdderTriageResult> _result = widget.estimator(widget.photo);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: AppColors.highlightSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Lectura de la foto (orientativa)', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            FutureBuilder<UdderTriageResult>(
              future: _result,
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Text('No se pudo analizar la foto.');
                if (!snapshot.hasData) return const LinearProgressIndicator();
                return Text(snapshot.data!.headline, style: theme.textTheme.bodyLarge);
              },
            ),
            const SizedBox(height: 8),
            Text(
              UdderTriageResult.disclaimer,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.warningText),
            ),
          ],
        ),
      ),
    );
  }
}
