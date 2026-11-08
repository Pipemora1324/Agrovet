import 'dart:typed_data';

/// Quita de un JPEG los segmentos de metadatos: EXIF y XMP (APP1, donde va la ubicación GPS),
/// IPTC (APP13) y comentarios (COM). La imagen no se vuelve a comprimir: los datos de la foto quedan
/// idénticos. Si los bytes no son un JPEG válido, lanza [FormatException].
Uint8List stripJpegMetadata(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
    throw const FormatException('El archivo no es una imagen JPEG.');
  }
  final out = BytesBuilder(copy: false)..add([0xFF, 0xD8]);
  var i = 2;
  while (i + 4 <= bytes.length) {
    if (bytes[i] != 0xFF) throw const FormatException('JPEG dañado.');
    final marker = bytes[i + 1];
    // Inicio de los datos de la imagen: de aquí al final se copia tal cual
    if (marker == 0xDA) {
      out.add(Uint8List.sublistView(bytes, i));
      return out.toBytes();
    }
    final length = (bytes[i + 2] << 8) | bytes[i + 3];
    final end = i + 2 + length;
    if (length < 2 || end > bytes.length) throw const FormatException('JPEG dañado.');
    final isMetadata = marker == 0xE1 || marker == 0xED || marker == 0xFE;
    if (!isMetadata) out.add(Uint8List.sublistView(bytes, i, end));
    i = end;
  }
  throw const FormatException('JPEG incompleto.');
}
