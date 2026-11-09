import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agrovet/data/local/app_database.dart';
import 'package:agrovet/data/local/local_repository.dart';
import 'package:agrovet/data/photos/jpeg_metadata.dart';
import 'package:agrovet/data/photos/photo_capture.dart';
import 'package:agrovet/data/photos/photo_store.dart';
import 'package:agrovet/domain/entities.dart';
import 'package:agrovet/presentation/photos/photos_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

List<int> _segment(int marker, List<int> payload) =>
    [0xFF, marker, (payload.length + 2) >> 8, (payload.length + 2) & 0xFF, ...payload];

/// JPEG mínimo con EXIF (ubicación GPS), comentario, tabla de cuantización y datos de imagen.
Uint8List jpegWithLocation() => Uint8List.fromList([
      0xFF, 0xD8, // SOI
      ..._segment(0xE0, ascii.encode('JFIF\x00\x01\x01')),
      ..._segment(0xE1, ascii.encode('Exif\x00\x00GPSLatitude=1.2136;GPSLongitude=-77.2811')),
      ..._segment(0xFE, ascii.encode('Finca La Esperanza')),
      ..._segment(0xDB, List.filled(65, 1)),
      ..._segment(0xDA, [1, 2, 3]),
      0x11, 0x22, 0x33, 0x44, // datos de la imagen
      0xFF, 0xD9, // EOI
    ]);

class _FakeCapture implements PhotoCapture {
  _FakeCapture(this.result);

  CaptureResult result;
  PhotoSource? lastSource;

  @override
  Future<CaptureResult> pick(PhotoSource source) async {
    lastSource = source;
    return result;
  }
}

void main() {
  group('metadatos del JPEG', () {
    test('quita EXIF (con la ubicación) y comentarios, y deja la imagen igual', () {
      final original = jpegWithLocation();
      final clean = stripJpegMetadata(original);
      final text = latin1.decode(clean);
      expect(text, isNot(contains('GPS')));
      expect(text, isNot(contains('Exif')));
      expect(text, isNot(contains('Esperanza')));
      expect(text, contains('JFIF'));
      // Desde el inicio del escaneo, los bytes son idénticos
      final sos = original.indexOf(0xDA) - 1;
      expect(clean.sublist(clean.length - (original.length - sos)), original.sublist(sos));
    });

    test('rechaza lo que no es JPEG', () {
      expect(() => stripJpegMetadata(Uint8List.fromList(ascii.encode('<html>no es foto</html>'))),
          throwsFormatException);
      expect(() => stripJpegMetadata(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE1, 0xFF, 0xFF])),
          throwsFormatException);
    });
  });

  group('fotos de una vaca', () {
    late AppDatabase db;
    late LocalRepository repo;
    late Directory dir;
    late PhotoStore store;
    final now = DateTime(2026, 11, 8, 9);

    setUp(() async {
      db = memoryDatabase();
      repo = LocalRepository(db, clock: () => now);
      await repo.saveCow(Cow(id: 'c1', tag: 'V-01', productionStatus: ProductionStatus.lactating, updatedAt: now));
      dir = Directory.systemTemp.createTempSync('agrovet_fotos_');
      store = await PhotoStore.forUser(dir, 'u1');
    });

    tearDown(() async {
      await db.close();
      dir.deleteSync(recursive: true);
    });

    PhotosCubit cubit(_FakeCapture capture) =>
        PhotosCubit(cowId: 'c1', repository: repo, store: store, capture: capture, clock: () => now);

    test('una foto de la cámara se guarda sin ubicación, con su fecha y pendiente de subir', () async {
      final capture = _FakeCapture(Captured(jpegWithLocation()));
      final photos = cubit(capture);
      await photos.add(PhotoSource.camera);

      expect(capture.lastSource, PhotoSource.camera);
      expect(photos.state.message, 'Foto guardada.');
      final saved = (await repo.watchPhotos('c1').first).single;
      expect(saved.takenOn, DateTime(2026, 11, 8));
      expect(saved.imageUploaded, isFalse);
      final bytes = await store.fileFor(saved.fileName).readAsBytes();
      expect(latin1.decode(bytes), isNot(contains('GPS')));
      expect(saved.sizeBytes, bytes.length);
      expect(store.fileFor(saved.fileName).path, startsWith(dir.path));
      final row = await db.select(db.cowPhotos).getSingle();
      expect(row.syncPending, isTrue);
      await photos.close();
    });

    test('cancelar no guarda nada y un permiso negado se explica', () async {
      final capture = _FakeCapture(const CaptureCancelled());
      final photos = cubit(capture);
      await photos.add(PhotoSource.gallery);
      expect(await repo.watchPhotos('c1').first, isEmpty);
      expect(photos.state.error, isNull);

      capture.result = CaptureFailed(SystemPhotoCapture.describe('camera_access_denied'));
      await photos.add(PhotoSource.camera);
      expect(photos.state.error, contains('Permisos'));
      await photos.close();
    });

    test('borrar quita el archivo y deja el borrado pendiente de sincronizar', () async {
      final photos = cubit(_FakeCapture(Captured(jpegWithLocation())));
      await photos.add(PhotoSource.gallery);
      final saved = (await repo.watchPhotos('c1').first).single;
      await photos.delete(saved);

      expect(await repo.watchPhotos('c1').first, isEmpty);
      expect(await store.fileFor(saved.fileName).exists(), isFalse);
      final row = await db.select(db.cowPhotos).getSingle();
      expect(row.deleted, isTrue);
      expect(row.syncPending, isTrue);
      await photos.close();
    });

    test('el permiso de investigación viene apagado y se guarda con la confirmación del veterinario', () async {
      final photos = cubit(_FakeCapture(Captured(jpegWithLocation())));
      await photos.add(PhotoSource.camera);
      final saved = (await repo.watchPhotos('c1').first).single;
      expect(saved.researchConsent, isFalse);
      expect(saved.usableForResearch, isFalse);

      await repo.savePhoto(saved.withResearch(
        vetConfirmed: VetConfirmation.yes,
        diagnosis: Diagnosis.mastitis,
        diagnosisNotes: 'Cuarto trasero izquierdo',
        researchConsent: true,
      ));
      final updated = (await repo.watchPhotos('c1').first).single;
      expect(updated.usableForResearch, isTrue);
      expect(updated.diagnosisNotes, 'Cuarto trasero izquierdo');
      expect((await db.select(db.cowPhotos).getSingle()).syncPending, isTrue);

      // Sin confirmación del veterinario o con diagnóstico "Otro" no sirve para entrenar
      expect(updated.withResearch(vetConfirmed: VetConfirmation.pending, diagnosis: Diagnosis.mastitis,
          researchConsent: true).usableForResearch, isFalse);
      expect(updated.withResearch(vetConfirmed: VetConfirmation.yes, diagnosis: Diagnosis.other,
          researchConsent: true).usableForResearch, isFalse);
      await photos.close();
    });

    test('al eliminar la cuenta se borran todas las fotos del usuario', () async {
      await store.save('p1', jpegWithLocation());
      await store.deleteAll();
      expect(await store.directory.exists(), isFalse);
    });
  });
}
