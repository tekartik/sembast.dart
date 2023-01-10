library sembast.database_utils_test;

import 'package:sembast/utils/database_utils.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('database_utils', () {
    test('getNonEmptyStoreNames', () async {
      var store = StoreRef('test');
      final db = await setupForTest(
          ctx, 'database_utils/get_non_empty_store_names.db');
      var record = store.record(1);

      expect(getNonEmptyStoreNames(db), isEmpty);
      await record.put(db, 'test');
      expect(getNonEmptyStoreNames(db), ['test']);
      await store.delete(db);
      expect(getNonEmptyStoreNames(db), isEmpty);
      await db.close();
    });
  });
}
