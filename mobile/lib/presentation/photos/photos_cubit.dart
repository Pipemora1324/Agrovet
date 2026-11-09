import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../data/photos/photo_capture.dart';
import '../../data/photos/photo_store.dart';
import '../../domain/entities.dart';
import '../../domain/repositories.dart';

class PhotosState extends Equatable {
  const PhotosState({this.busy = false, this.message, this.error});

  final bool busy;
  final String? message;
  final String? error;

  @override
  List<Object?> get props => [busy, message, error];
}

/// Agregar y borrar fotos de una vaca. La lista se lee directamente del repositorio (stream).
class PhotosCubit extends Cubit<PhotosState> {
  PhotosCubit({
    required this.cowId,
    required this.repository,
    required this.store,
    required this.capture,
    DateTime Function()? clock,
    Uuid? uuid,
  })  : _now = clock ?? DateTime.now,
        _uuid = uuid ?? const Uuid(),
        super(const PhotosState());

  final String cowId;
  final PhotoRepository repository;
  final PhotoStore store;
  final PhotoCapture capture;
  final DateTime Function() _now;
  final Uuid _uuid;

  Future<void> add(PhotoSource source) async {
    emit(const PhotosState(busy: true));
    final result = await capture.pick(source);
    switch (result) {
      case CaptureCancelled():
        emit(const PhotosState());
      case CaptureFailed(:final message):
        emit(PhotosState(error: message));
      case Captured(:final bytes):
        try {
          final id = _uuid.v4();
          final saved = await store.save(id, bytes);
          final now = _now();
          await repository.savePhoto(CowPhoto(
            id: id,
            cowId: cowId,
            takenOn: dateOnly(now),
            fileName: saved.fileName,
            sizeBytes: saved.sizeBytes,
            createdAt: now,
          ));
          emit(const PhotosState(message: 'Foto guardada.'));
        } on FormatException {
          emit(const PhotosState(error: 'La foto no es una imagen JPEG válida.'));
        }
    }
  }

  Future<void> delete(CowPhoto photo) async {
    await repository.deletePhoto(photo.id);
    await store.delete(photo.fileName);
    emit(const PhotosState(message: 'Foto borrada.'));
  }
}
