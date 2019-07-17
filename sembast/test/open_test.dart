library sembast.open_test;

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  var factory = ctx.factory;
  group('open', () {
    test('no_version', () async {
      var path = dbPathFromName('open/no_version.db');

      await factory.deleteDatabase(path);

      var db = await factory.openDatabase(path,
          onVersionChanged: (db, oldVersion, newVersion) async {
        expect(oldVersion, 0);
        expect(db.version, 0);
      });
      expect(db.version, 1);
      await db.close();
    });
    test('version', () async {
      var path = dbPathFromName('open/version.db');

      await factory.deleteDatabase(path);

      var db = await factory.openDatabase(path, version: 1,
          onVersionChanged: (db, oldVersion, newVersion) async {
        expect(oldVersion, 0);
        expect(db.version, 0);
      });
      expect(db.version, 1);
      await db.close();

      db = await factory.openDatabase(path, version: 2,
          onVersionChanged: (db, oldVersion, newVersion) async {
        expect(oldVersion, 1);
        expect(db.version, 1);
      });
      expect(db.version, 2);
    });

    test('compacting during open', () async {
      // Deleting all the records during onVersionChanged could trigger
      // a compact that hangs the database
      // fixed in 1.16.0+1
      var store = StoreRef<int, int>.main();

      Future<Database> openDatabase(String path, int version) async {
        return await factory.openDatabase(path, version: version,
            onVersionChanged: (db, oldVersion, newVersion) async {
          if (oldVersion == 1 && newVersion == 2) {
            await db.transaction((txn) async {
              var records = await store.find(txn);

              for (var item in records) {
                await store.delete(txn,
                    finder: Finder(filter: Filter.byKey(item.key)));
              }
            });
          }
        });
      }

      var path = dbPathFromName('open/compacting_during_open.db');

      await factory.deleteDatabase(path);

      var db = await openDatabase(path, 1);
      // Add 21 records
      await db.transaction((txn) async {
        for (var i = 1; i < 21; i++) {
          await store.add(txn, i);
        }
      });
      await db.close();

      db = await openDatabase(path, 2);
      await db.close();
    });
  });
}
