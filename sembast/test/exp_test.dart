library sembast.test.exp_test;

import 'dart:async';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('exp', () {
    Database db;

    setUp(() async {});

    tearDown(() async {
      if (db != null) {
        await db.close();
        db = null;
      }
    });

    test('issue8_1', () async {
      db = await setupForTest(ctx, 'exp/issue8_1');
      var store = StoreRef.main();
      dynamic lastKey;
      var macAddress = '00:0a:95:9d:68:16';
      await db.transaction((txn) async {
        // put twice the same record
        await store.add(txn, {'macAddress': macAddress});
        lastKey = await store.add(txn, {'macAddress': macAddress});
      });
      // Sorting by key requires using the special Field.key
      var finder = Finder(
          filter: Filter.equals('macAddress', macAddress),
          sortOrders: [SortOrder(Field.key, false)]);
      // finding one record automatically set limit to 1
      expect((await store.findFirst(db, finder: finder)).key, lastKey);
    });

    test('issue8_2', () async {
      var beaconsStoreName = 'beacons';
      var store = StoreRef(beaconsStoreName);
      db = await setupForTest(ctx, 'exp/issue8_2');

      dynamic key2, key3;
      await db.transaction((txn) async {
        await store.add(txn, {'name': 'beacon1'});
        key2 = await store.add(txn, {'name': 'beacon2'});
        key3 = await store.add(txn, {'name': 'beacon3'});
      });

      var recordsIds = [key2, key3];
      await db.transaction((txn) async {
        List<Future> futures = [];
        recordsIds.forEach((key) =>
            futures.add(store.record(key).update(txn, {'flushed': true})));
        await Future.wait(futures);
      });

      expect(await store.records(await store.findKeys(db)).get(db), [
        {'name': 'beacon1'},
        {'name': 'beacon2', 'flushed': true},
        {'name': 'beacon3', 'flushed': true}
      ]);
    });
  });
}
