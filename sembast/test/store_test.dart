library sembast.test.src_store_test;

import 'package:sembast/src/sembast_impl.dart';

import 'test_common.dart';

void main() {
  defineStoreTests(memoryDatabaseContext);
}

void defineStoreTests(DatabaseTestContext ctx) {
  group('store', () {
    late Database db;

    setUp(() async {
      db = await setupForTest(ctx, 'store.db');
    });

    tearDown(() {
      return db.close();
    });

    test('find_with_limit_optimizations', () async {
      // Simple code to debug
      var store = StoreRef<int, String>('test');
      var record = store.record(1);
      await record.put(db, 'test');
      var record2 = store.record(2);
      await record2.put(db, 'test');
      expect(await store.findKey(db, finder: Finder(limit: 1)), 1);
      expect(await store.findKey(db, finder: Finder(offset: 1, limit: 1)), 2);
    });

    test('count_optimization', () async {
      // Simple code to debug
      var store = StoreRef<int, String>('test');
      var record = store.record(1);

      var countListFuture = store.onCount(db).take(3).toList();
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

      await record.delete(db);
      expect(await store.count(db), 0);
      expect(await countListFuture, [0, 1, 0]);
    });

    test('drop_and_add_in_transaction', () async {
      var store = StoreRef<int, String>('test');
      var record = store.record(1);

      // Drop non existing store
      await db.transaction((txn) async {
        await store.drop(txn);
        await record.put(txn, 'test1');
      });
      expect(await record.get(db), 'test1');

      await db.transaction((txn) async {
        await store.drop(txn);
        await record.put(txn, 'test2');
      });
      expect(await record.get(db), 'test2');
    });

    test('generateKey', () async {
      var store = StoreRef<int, String>('int_key');
      expect(await store.generateKey(db), 1);
      expect(await store.generateKey(db), 2);
      // In transaction
      await db.transaction((txn) async {
        expect(await store.generateKey(txn), 3);
      });
      var storeString = StoreRef<String, String>('string_key');
      var key1 = await storeString.generateKey(db);
      var key2 = await storeString.generateKey(db);
      expect(key1.length, greaterThan(10));
      expect(key2.length, greaterThan(10));
      expect(key1, isNot(key2));

      expect(await intMainStoreRef.generateKey(db), 1);
      expect(await stringMainStoreRef.generateKey(db), isNotEmpty);
    });

    test('generateIntKey', () async {
      var store = StoreRef<int, String>('int_key');
      expect(await store.generateIntKey(db), 1);
      expect(await store.generateIntKey(db), 2);
      // In transaction
      await db.transaction((txn) async {
        expect(await store.generateIntKey(txn), 3);
      });
      var storeString = StoreRef<String, String>('string_key');
      var key1 = await storeString.generateIntKey(db);
      var key2 = await storeString.generateIntKey(db);

      expect(key1, 1);
      expect(key2, 2);
    });
  });
}
