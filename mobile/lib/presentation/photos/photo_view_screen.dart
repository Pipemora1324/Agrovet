import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/formatters.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../data/photos/photo_store.dart';
import '../../domain/entities.dart';
import '../../domain/repositories.dart';
import '../widgets/big_button.dart';

/// Foto en grande (con zoom), sus datos opcionales para investigación y la opción de borrarla.
class PhotoViewScreen extends StatelessWidget {
  const PhotoViewScreen({super.key, required this.photo, this.onDelete});

  final CowPhoto photo;
  final Future<void> Function(CowPhoto photo)? onDelete;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar esta foto?'),
        content: const Text('La foto se quitará de la ficha de esta vaca.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: AppButtonStyles.dangerFilled(context),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await onDelete!(photo);
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(formatDay(photo.takenOn)),
      actions: [
        if (onDelete != null)
          IconButton(
            tooltip: 'Borrar foto',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  child: SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.45,
                    child: InteractiveViewer(
                      maxScale: 5,
                      child: Image.file(
                        context.read<PhotoStore>().fileFor(photo.fileName),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _ResearchForm(photo: photo),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Opciones excluyentes y opcionales (se puede desmarcar). En horizontal si cada opción cabe en una
/// línea; si no (letra grande o pantalla angosta), una debajo de otra, para no partir palabras.
class _Choices<T> extends StatelessWidget {
  const _Choices({required this.options, required this.selected, required this.onChanged});

  final Map<T, String> options;
  final T? selected;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = Theme.of(context).segmentedButtonTheme.style?.textStyle?.resolve({});
      final scaler = MediaQuery.textScalerOf(context);
      final widest = options.values
          .map((label) => (TextPainter(
                text: TextSpan(text: label, style: style),
                textScaler: scaler,
                textDirection: TextDirection.ltr,
                maxLines: 1,
              )..layout()).width)
          .reduce((a, b) => a > b ? a : b);
      // Texto + relleno (16) + bordes; sin ícono de marcado (lo elegido se ve por el color)
      final fits = widest + 24 <= constraints.maxWidth / options.length;
      return SegmentedButton<T>(
        direction: fits ? Axis.horizontal : Axis.vertical,
        // En vertical, la píldora del tema se vería como un óvalo
        style: fits
            ? null
            : SegmentedButton.styleFrom(
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.field),
              ),
        showSelectedIcon: false,
        emptySelectionAllowed: true,
        segments: [
          for (final MapEntry(key: value, value: label) in options.entries)
            ButtonSegment(value: value, label: Text(label)),
        ],
        selected: {?selected},
        onSelectionChanged: (selection) => onChanged(selection.firstOrNull),
      );
    },
  );
}

/// Datos opcionales para investigación, plegados por defecto: confirmación del veterinario,
/// diagnóstico y permiso expreso para usar la foto (apagado por defecto). Solo las fotos con permiso,
/// confirmadas y con diagnóstico claro sirven para entrenar la CNN (ml/src/build_cnn_dataset.py).
class _ResearchForm extends StatefulWidget {
  const _ResearchForm({required this.photo});

  final CowPhoto photo;

  @override
  State<_ResearchForm> createState() => _ResearchFormState();
}

class _ResearchFormState extends State<_ResearchForm> {
  late VetConfirmation? _vet = widget.photo.vetConfirmed;
  late Diagnosis? _diagnosis = widget.photo.diagnosis;
  late bool _consent = widget.photo.researchConsent;
  late final _notes = TextEditingController(text: widget.photo.diagnosisNotes);
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await context.read<PhotoRepository>().savePhoto(
      widget.photo.withResearch(
        vetConfirmed: _vet,
        diagnosis: _diagnosis,
        diagnosisNotes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        researchConsent: _consent,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Datos de la foto guardados.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text('Para investigación (opcional)', style: theme.textTheme.titleMedium),
        subtitle: const Text('Diagnóstico del veterinario y permiso de uso'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('¿Un veterinario confirmó el diagnóstico?', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          _Choices<VetConfirmation>(
            options: {for (final option in VetConfirmation.values) option: option.label},
            selected: _vet,
            onChanged: (value) => setState(() => _vet = value),
          ),
          const SizedBox(height: 16),
          Text('Diagnóstico', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          _Choices<Diagnosis>(
            options: {for (final option in Diagnosis.values) option: option.label},
            selected: _diagnosis,
            onChanged: (value) => setState(() => _diagnosis = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLength: 300,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notas (opcional)'),
          ),
          const Divider(height: 24),
          SwitchListTile(
            value: _consent,
            onChanged: (value) => setState(() => _consent = value),
            contentPadding: EdgeInsets.zero,
            title: const Text('Permitir usar esta foto para investigación'),
            subtitle: const Text(
              'Ayuda a entrenar un modelo que reconozca la mastitis en fotos. Se usa sin datos que lo '
              'identifiquen y puede quitar el permiso cuando quiera.',
            ),
          ),
          const SizedBox(height: 12),
          BigButton(icon: Icons.save, label: 'Guardar', busy: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
