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
      await StoreRef<Object, Object>('test').drop(db);
      expect(db.storeNames, ['_main']);
    });

    test('delete_main', () async {
      expect(db.storeNames, ['_main']);
      await StoreRef<Object, Object>.main().drop(db);
      expect(db.storeNames, ['_main']);
    });

    test('put/delete_store', () async {
      var store = StoreRef<Object, Object>('test');
      var record = store.record(1);
      await record.put(db, 'test');
      expect(db.storeNames, contains('test'));
      await store.drop(db);
      expect(db.storeNames, isNot(contains('test')));
      expect(await record.get(db), isNull);
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

      var storeObject = StoreRef<Object, String>('object_key');
      await expectLater(
          () => storeObject.generateKey(db), throwsA(isA<ArgumentError>()));
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
      var storeObject = StoreRef<Object, String>('object_key');
      key1 = await storeObject.generateIntKey(db);
      key2 = await storeObject.generateIntKey(db);
      expect(key1, 1);
      expect(key2, 2);
    });
  });
}
