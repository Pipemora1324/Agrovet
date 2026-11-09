import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config.dart';
import '../../core/formatters.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../data/photos/photo_store.dart';
import '../../domain/entities.dart';
import '../../domain/repositories.dart';
import '../widgets/big_button.dart';
import 'udder_triage_card.dart';

/// Foto en grande (con zoom), sus datos para investigación y la opción de borrarla.
class PhotoViewScreen extends StatelessWidget {
  const PhotoViewScreen({super.key, required this.photo, this.onDelete});

  final CowPhoto photo;
  final Future<void> Function(CowPhoto photo)? onDelete;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar esta foto?'),
        content: const Text('Se borra de este celular y, al sincronizar, del servidor.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
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
                          child: Image.file(context.read<PhotoStore>().fileFor(photo.fileName)),
                        ),
                      ),
                    ),
                    if (AppConfig.udderTriageEnabled) ...[
                      const SizedBox(height: 16),
                      UdderTriageCard(photo: context.read<PhotoStore>().fileFor(photo.fileName)),
                    ],
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

/// Confirmación del veterinario, diagnóstico y permiso para investigación.
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
    await context.read<PhotoRepository>().savePhoto(widget.photo.withResearch(
          vetConfirmed: _vet,
          diagnosis: _diagnosis,
          diagnosisNotes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          researchConsent: _consent,
        ));
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datos de la foto guardados.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Para investigación (opcional)', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Text('¿Un veterinario confirmó el diagnóstico?', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<VetConfirmation>(
              emptySelectionAllowed: true,
              segments: [
                for (final option in VetConfirmation.values) ButtonSegment(value: option, label: Text(option.label)),
              ],
              selected: {?_vet},
              onSelectionChanged: (selection) => setState(() => _vet = selection.firstOrNull),
            ),
            const SizedBox(height: 16),
            Text('Diagnóstico', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<Diagnosis>(
              emptySelectionAllowed: true,
              segments: [
                for (final option in Diagnosis.values) ButtonSegment(value: option, label: Text(option.label)),
              ],
              selected: {?_diagnosis},
              onSelectionChanged: (selection) => setState(() => _diagnosis = selection.firstOrNull),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLength: 300,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notas del diagnóstico (opcional)'),
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
      ),
    );
  }
}
