import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/formatters.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../data/photos/photo_store.dart';
import '../../domain/entities.dart';

/// Foto en grande (con zoom) y la opción de borrarla.
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
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
