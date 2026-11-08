import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/responsive.dart';
import '../../data/photos/photo_capture.dart';
import '../../data/photos/photo_store.dart';
import '../../domain/entities.dart';
import '../../domain/repositories.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/notice_box.dart';
import 'photo_gallery.dart';
import 'photos_cubit.dart';

/// Fotos de una vaca: tomar con la cámara, elegir de la galería y ver las anteriores.
class CowPhotosScreen extends StatelessWidget {
  const CowPhotosScreen({super.key, required this.cow});

  final Cow cow;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) => PhotosCubit(
          cowId: cow.id,
          repository: context.read<PhotoRepository>(),
          store: context.read<PhotoStore>(),
          capture: context.read<PhotoCapture>(),
        ),
        child: _CowPhotosView(cow: cow),
      );
}

class _CowPhotosView extends StatelessWidget {
  const _CowPhotosView({required this.cow});

  final Cow cow;

  Future<void> _choose(BuildContext context) async {
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, size: 32),
              title: const Text('Tomar foto con la cámara'),
              onTap: () => Navigator.pop(context, PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, size: 32),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, PhotoSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source != null && context.mounted) await context.read<PhotosCubit>().add(source);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<PhotosCubit, PhotosState>(
      listenWhen: (previous, current) => current.message != null && previous.message != current.message,
      listener: (context, state) =>
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message!))),
      child: AppScaffold(
        title: 'Fotos · ${cow.name ?? cow.tag}',
        floatingActionButton: BlocBuilder<PhotosCubit, PhotosState>(
          builder: (context, state) => FloatingActionButton.extended(
            onPressed: state.busy ? null : () => _choose(context),
            icon: state.busy
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))
                : const Icon(Icons.add_a_photo, size: 28),
            label: const Text('Agregar foto'),
          ),
        ),
        body: StreamBuilder<List<CowPhoto>>(
          stream: context.read<PhotoRepository>().watchPhotos(cow.id),
          builder: (context, snapshot) {
            final photos = snapshot.data ?? const <CowPhoto>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
              children: [
                CenteredContent(
                  maxWidth: 1100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BlocBuilder<PhotosCubit, PhotosState>(
                        builder: (context, state) => state.error == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: NoticeBox.error(state.error!),
                              ),
                      ),
                      Text(
                        'Las fotos quedan guardadas solo dentro de AgroVet, sin la ubicación, y se suben al '
                        'servidor cuando hay internet.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      if (photos.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.photo_camera_back, size: 72, color: theme.colorScheme.primary),
                              const SizedBox(height: 12),
                              Text('Todavía no hay fotos de esta vaca.', style: theme.textTheme.titleMedium),
                            ],
                          ),
                        )
                      else
                        PhotoGallery(photos: photos, onDelete: context.read<PhotosCubit>().delete),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
