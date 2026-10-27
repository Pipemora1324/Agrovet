import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'app_database.dart';

/// Abre la base local cifrada con SQLCipher.
///
/// La clave (32 bytes aleatorios en hexadecimal) vive en el almacenamiento seguro del sistema,
/// nunca en el código ni junto al archivo. Si la biblioteca cargada no es SQLCipher, se aborta
/// en vez de guardar datos sin cifrar.
class DatabaseOpener {
  static final _hexKey = RegExp(r'^[0-9a-f]{64}$');

  static Future<AppDatabase> openForUser({required String userId, required String hexKey}) async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'agrovet_${_safeName(userId)}.db'));
    return AppDatabase(openFile(file, hexKey));
  }

  static QueryExecutor openFile(File file, String hexKey) {
    if (!_hexKey.hasMatch(hexKey)) {
      throw ArgumentError('La clave de la base debe ser hexadecimal de 64 caracteres');
    }
    return NativeDatabase.createInBackground(
      file,
      setup: (db) => applyKey(db, hexKey),
    );
  }

  /// Aplica la clave como clave cruda (sin derivación) y verifica que SQLCipher esté activo.
  static void applyKey(Database db, String hexKey) {
    final version = db.select('PRAGMA cipher_version;');
    if (version.isEmpty || (version.first.values.first as String?)?.isEmpty != false) {
      throw StateError('SQLCipher no está disponible: no se abre la base sin cifrado');
    }
    // La clave solo contiene [0-9a-f], validado arriba, así que no hay riesgo de inyección
    db.execute("PRAGMA key = \"x'$hexKey'\";");
    // Fuerza la lectura del encabezado: falla aquí si la clave no corresponde
    db.select('SELECT count(*) FROM sqlite_master;');
  }

  static String _safeName(String value) => value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
}
