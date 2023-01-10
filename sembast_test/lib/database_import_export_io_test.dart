@TestOn('vm') // Temp
library sembast.database_import_export_encrypt_test;

import 'package:sembast/timestamp.dart';
import 'package:sembast/utils/sembast_import_export.dart';
import 'package:sembast_test/encrypt_codec.dart';

import 'test_common.dart';

void main() {
  databaseImportExportIoGroup(memoryDatabaseContext);
}

void databaseImportExportIoGroup(DatabaseTestContext ctx) {
  var factory = ctx.factory;

  group('import_export_encrypt', () {
    test('migrate to encrypted', () async {
      var nonEncryptedDbPath = dbPathFromName('non_encrypted.db');
      var encryptedDbPath = dbPathFromName('encrypted.db');
      var store = StoreRef<int, Object>.main();

      // Prepare
      var db = await factory.openDatabase(nonEncryptedDbPath);
      // Add a record
      var key1 = await store.add(db, 'test');
      var key2 = await store.add(db, Timestamp(1, 2));
      await db.close();

      // Migration to encrypted db
      var codec = getEncryptSembastCodec(password: 'test');

      // First export and close the existing database
      var exportMap = await exportDatabase(db);
      await db.close();

      // Import as new encrypted database
      db = await importDatabase(exportMap, factory, encryptedDbPath,
          codec: codec);

      // Test still present
      expect(await store.record(key1).get(db), 'test');
      expect(await store.record(key2).get(db), Timestamp(1, 2));
      await db.close();

      // Reopen the database
      db = await factory.openDatabase(encryptedDbPath, codec: codec);
      expect(await store.record(key1).get(db), 'test');
      expect(await store.record(key2).get(db), Timestamp(1, 2));
      await db.close();
    });
  });
}
