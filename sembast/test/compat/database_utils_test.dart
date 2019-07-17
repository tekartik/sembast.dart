library sembast.database_utils_test;

// ignore_for_file: deprecated_member_use_from_same_package

import 'package:sembast/sembast.dart';
import 'package:sembast/utils/database_utils.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('utils', () {
    Database db;

    setUp(() async {});

    tearDown(() async {
      if (db != null) {
        await db.close();
        db = null;
      }
    });

    test('updateRecords', () async {
      db = await setupForTest(ctx, 'compat/utils/update_records.db');

      // Store some objects
      dynamic key1, key2, key3;
      await db.transaction((txn) async {
        var store = txn.getStore('animals');
        key1 = await store.put({'name': 'fish'});
        key2 = await store.put({'name': 'cat'});
        key3 = await store.put({'name': 'dog'});
      });

      // Filter for updating records
      var finder = Finder(filter: Filter.greaterThan('name', 'cat'));

      // Update without transaction
      var store = db.getStore('animals');
      await updateRecords(store, {'age': 4}, where: finder);
      expect(getRecordsValues(await store.getRecords([key1, key2, key3])), [
        {'name': 'fish', 'age': 4},
        {'name': 'cat'},
        {'name': 'dog', 'age': 4}
      ]);

      // Update within transaction
      await db.transaction((txn) async {
        var store = txn.getStore('animals');
        await updateRecords(store, {'age': 5}, where: finder);
      });
      expect(getRecordsValues(await store.getRecords([key1, key2, key3])), [
        {'name': 'fish', 'age': 5},
        {'name': 'cat'},
        {'name': 'dog', 'age': 5}
      ]);
    });
  });
}
