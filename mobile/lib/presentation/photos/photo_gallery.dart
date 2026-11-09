import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/photos/photo_store.dart';
import '../../domain/entities.dart';
import 'photo_view_screen.dart';

/// Cuadrícula de fotos con la fecha de cada una. Al tocar una, se abre en grande.
class PhotoGallery extends StatelessWidget {
  const PhotoGallery({super.key, required this.photos, this.onDelete});

  final List<CowPhoto> photos;
  final Future<void> Function(CowPhoto photo)? onDelete;

  @override
  Widget build(BuildContext context) {
    final store = context.read<PhotoStore>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 160).floor().clamp(2, 6);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: photos.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final photo = photos[index];
            return Semantics(
              label: 'Foto: ${formatDay(photo.takenOn).toLowerCase()}',
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.small),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RepositoryProvider.value(
                      value: store,
                      child: PhotoViewScreen(photo: photo, onDelete: onDelete),
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        store.fileFor(photo.fileName),
                        fit: BoxFit.cover,
                        cacheWidth: 400,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: AppColors.riskNone,
                          child: Icon(Icons.broken_image, size: 40),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          color: AppColors.notice.withValues(alpha: 0.75),
                          child: Text(
                            formatShortDay(photo.takenOn),
                            style: Theme.of(context).textTheme.chip.copyWith(color: AppColors.onNotice),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
