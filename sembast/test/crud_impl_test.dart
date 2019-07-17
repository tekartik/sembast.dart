library sembast.test.crud_impl_test;

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('crud_impl', () {
    Database db;

    var store = StoreRef.main();

    setUp(() async {
      db = await setupForTest(ctx, 'crud_impl.db');
    });

    tearDown(() {
      return db.close();
    });

    test('put_close_get', () async {
      var record = store.record(1);
      await record.put(db, "hi");
      await reOpen(db);

      expect(await record.get(db), "hi");
    });

    test('put_nokey_close_put', () async {
      expect(await store.add(db, 'hi'), 1);
      await reOpen(db);
      expect(await store.add(db, 'hi'), 2);
    });

    test('put_update_close_get', () async {
      var record = store.record(1);
      await record.put(db, "hi");
      await record.put(db, "ho");
      await reOpen(db);
      expect(await record.get(db), "ho");
      expect(await store.count(db), 1);
    });

    test('put_delete_close_get', () async {
      var record = store.record(1);
      await record.put(db, "hi");
      await record.delete(db);
      await reOpen(db);
      expect(await record.get(db), isNull);
      expect(await store.count(db), 0);
    });

    test('put_close_get_key_string', () async {
      var record = store.record("1");
      await record.put(db, "hi");
      await reOpen(db);
      expect(await record.get(db), "hi");
    });

    test('put_close_get_map', () async {
      var record = store.record(1);
      Map info = {"info": 12};
      await record.put(db, info);
      await reOpen(db);
      var infoRead = await record.get(db);
      expect(infoRead, info);
      expect(identical(infoRead, info), isFalse);
    });
  });
}
