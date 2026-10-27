import 'dart:io';

import 'package:agrovet/data/local/database_opener.dart';
import 'package:agrovet/data/security/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('agrovet_db_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('la biblioteca cargada es SQLCipher', () {
    final db = sqlite3.openInMemory();
    final version = db.select('PRAGMA cipher_version;');
    db.close();
    expect(version, isNotEmpty);
    expect(version.first.values.first, isA<String>());
  });

  test('el archivo queda cifrado: sin la clave no se puede leer', () {
    final file = File('${dir.path}/prueba.db');
    final key = SecureStore.generateHexKey();

    final db = sqlite3.open(file.path);
    DatabaseOpener.applyKey(db, key);
    db.execute("CREATE TABLE cows (tag TEXT); INSERT INTO cows VALUES ('VACA-SECRETA');");
    db.close();

    // El texto no aparece en claro dentro del archivo
    expect(String.fromCharCodes(file.readAsBytesSync()).contains('VACA-SECRETA'), isFalse);

    final withoutKey = sqlite3.open(file.path);
    expect(() => withoutKey.select('SELECT * FROM cows'), throwsA(isA<SqliteException>()));
    withoutKey.close();

    final wrongKey = sqlite3.open(file.path);
    expect(() => DatabaseOpener.applyKey(wrongKey, SecureStore.generateHexKey()),
        throwsA(isA<SqliteException>()));
    wrongKey.close();

    final withKey = sqlite3.open(file.path);
    DatabaseOpener.applyKey(withKey, key);
    expect(withKey.select('SELECT tag FROM cows').first['tag'], 'VACA-SECRETA');
    withKey.close();
  });

  test('la clave generada es hexadecimal de 64 caracteres', () {
    expect(SecureStore.generateHexKey(), matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(SecureStore.generateHexKey(), isNot(SecureStore.generateHexKey()));
  });

  test('se rechaza una clave con caracteres no hexadecimales', () {
    expect(() => DatabaseOpener.openFile(File('${dir.path}/x.db'), "abc'; DROP"),
        throwsArgumentError);
  });
}
