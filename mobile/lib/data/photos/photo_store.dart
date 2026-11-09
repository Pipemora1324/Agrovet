import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'jpeg_metadata.dart';

/// Archivos de las fotos en el almacenamiento privado de la app (otras apps no pueden leerlo y no
/// se incluye en los respaldos de Android). Una carpeta por usuario.
class PhotoStore {
  PhotoStore(this.directory);

  final Directory directory;

  static Future<PhotoStore> forUser(Directory appSupport, String userId) async {
    final dir = Directory(p.join(appSupport.path, 'photos', userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')));
    await dir.create(recursive: true);
    return PhotoStore(dir);
  }

  File fileFor(String fileName) => File(p.join(directory.path, p.basename(fileName)));

  /// Guarda la foto sin metadatos (sin ubicación) y devuelve el nombre y el tamaño final.
  Future<({String fileName, int sizeBytes})> save(String photoId, Uint8List jpeg) async {
    final clean = stripJpegMetadata(jpeg);
    final fileName = '$photoId.jpg';
    await fileFor(fileName).writeAsBytes(clean, flush: true);
    return (fileName: fileName, sizeBytes: clean.length);
  }

  Future<void> delete(String fileName) async {
    final file = fileFor(fileName);
    if (await file.exists()) await file.delete();
  }

  /// Borra todas las fotos del usuario (al eliminar la cuenta).
  Future<void> deleteAll() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
