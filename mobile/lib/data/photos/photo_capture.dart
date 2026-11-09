import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

enum PhotoSource { camera, gallery }

/// Resultado de pedir una foto: los bytes ya reducidos, nada (canceló) o un mensaje de error.
sealed class CaptureResult {
  const CaptureResult();
}

class Captured extends CaptureResult {
  const Captured(this.bytes);

  final Uint8List bytes;
}

class CaptureCancelled extends CaptureResult {
  const CaptureCancelled();
}

class CaptureFailed extends CaptureResult {
  const CaptureFailed(this.message);

  final String message;
}

/// Toma una foto con la cámara o la elige de la galería, reducida y comprimida.
///
/// En Android, la cámara se abre con la app de cámara del sistema y la galería con el selector de
/// fotos del sistema: AgroVet no necesita permiso para leer todas las fotos del celular. Si la
/// persona negó el acceso, se le explica cómo darlo.
abstract interface class PhotoCapture {
  Future<CaptureResult> pick(PhotoSource source);
}

class SystemPhotoCapture implements PhotoCapture {
  SystemPhotoCapture([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Lado mayor y calidad JPEG: suficiente para ver la ubre y liviano para subir con poca señal.
  static const maxSide = 1280.0;
  static const quality = 75;
  static const maxBytes = 5 * 1024 * 1024;

  @override
  Future<CaptureResult> pick(PhotoSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: maxSide,
        maxHeight: maxSide,
        imageQuality: quality,
        requestFullMetadata: false,
      );
      if (file == null) return const CaptureCancelled();
      final bytes = await file.readAsBytes();
      if (bytes.length > maxBytes) {
        return const CaptureFailed(
          'La foto pesa demasiado. Intente tomarla de nuevo con menor resolución.',
        );
      }
      return Captured(bytes);
    } on PlatformException catch (e) {
      return CaptureFailed(describe(e.code));
    } on FileSystemException {
      return const CaptureFailed(
        'No se pudo obtener la foto. Revise el espacio disponible e intente de nuevo.',
      );
    }
  }

  static String describe(String code) => switch (code) {
    'camera_access_denied' => 'AgroVet no tiene permiso para usar la cámara. Actívelo en Ajustes > Aplicaciones > AgroVet > Permisos.',
    'photo_access_denied' => 'AgroVet no tiene permiso para ver sus fotos. Actívelo en Ajustes > Aplicaciones > AgroVet > Permisos.',
    'no_available_camera' => 'Este celular no tiene una cámara disponible.',
    _ => 'No se pudo obtener la foto. Intente de nuevo.',
  };
}
