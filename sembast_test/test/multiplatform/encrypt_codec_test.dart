import 'dart:convert';

import 'package:sembast/src/memory/file_system_memory.dart';
import 'package:sembast/src/sembast_fs.dart';
import 'package:sembast_test/encrypt_codec.dart';
import 'package:sembast_test/test_common.dart';

void main() {
  test('EncryptedDatabaseFactory', () async {
    var fs = FileSystemMemory();
    var factory = DatabaseFactoryFs(fs);
    var dbPath = 'test';
    var encryptedFactory = EncryptedDatabaseFactory(
      databaseFactory: factory,
      password: 'user_password',
    );
    var db = await encryptedFactory.openDatabase(dbPath);
    var store = StoreRef<int, String>.main();
    await store.add(db, 'test');
    await db.close();
    final lines = await readContent(fs, dbPath);
    print(lines);
    expect(lines.length, 2);
    var codec = encryptedFactory.codec.codec!;
    expect(codec.decode((json.decode(lines.first) as Map)['codec'] as String), {
      'signature': 'encrypt',
    });
    expect(codec.decode(lines[1]), {'key': 1, 'value': 'test'});
  });
}
