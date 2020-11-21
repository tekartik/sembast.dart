library sembast.test.src_store_test;

import 'package:sembast/src/database_impl.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('src_store', () {
    late SembastDatabase db;

    setUp(() async {
      db = await setupForTest(ctx, 'src_store.db') as SembastDatabase;
    });

    tearDown(() {
      return db.close();
    });

    test('delete', () async {
      expect(db.storeNames, ['_main']);
      await StoreRef('test').drop(db);
      expect(db.storeNames, ['_main']);
    });

    test('delete_main', () async {
      expect(db.storeNames, ['_main']);
      await StoreRef.main().drop(db);
      expect(db.storeNames, ['_main']);
    });

    test('put/delete_store', () async {
      var store = StoreRef('test');
      var record = store.record(1);
      await record.put(db, 'test');
      expect(db.storeNames, contains('test'));
      await store.drop(db);
      expect(db.storeNames, isNot(contains('test')));
      expect(await record.get(db), isNull);
    });

    test('find_with_limit_optimizations', () async {
      // Simple code to debug
      var store = StoreRef('test');
      var record = store.record(1);
      await record.put(db, 'test');
      var record2 = store.record(2);
      await record2.put(db, 'test');
      expect(await store.findKey(db, finder: Finder(limit: 1)), 1);
      expect(await store.findKey(db, finder: Finder(offset: 1, limit: 1)), 2);
    });

    test('count_optimization', () async {
      // Simple code to debug
      var store = StoreRef('test');
      var record = store.record(1);
      await record.put(db, 'test');
      expect(await store.count(db), 1);
      try {
        await db.transaction((txn) async {
          expect(await store.count(txn), 1);
          var record2 = store.record(2);
          await record2.put(txn, 'test');
          expect(await store.count(txn), 2);
          throw 'cancel';
        });
      } catch (_) {}
      expect(await store.count(db), 1);
    });
  });
}
