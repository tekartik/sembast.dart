library sembast.open_test;

// basically same as the io runner but with extra output
import 'package:sembast/src/api/sembast.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  var factory = ctx.factory;
  group('open', () {
    test('compacting during open', () async {
      // Deleting all the records during onVersionChanged could trigger
      // a compact that hangs the database
      // fixed in 1.16.0+1
      var store = StoreRef<int, int>.main();

      Future<Database> openDatabase(String path, int version) async {
        return await factory.openDatabase(path, version: version,
            onVersionChanged: (dataBase, oldVersion, newVersion) async {
          if (oldVersion == 1 && newVersion == 2) {
            await dataBase.transaction((txn) async {
              var records = await store.find(txn);

              for (var item in records) {
                await store.delete(txn,
                    finder: Finder(filter: Filter.byKey(item.key)));
              }
            });
          }
        });
      }

      var path = ctx.dbPath;

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
