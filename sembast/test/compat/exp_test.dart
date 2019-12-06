library sembast.test.compat.exp_test;

// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';

import 'package:sembast/sembast.dart';

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
      db = await setupForTest(ctx, 'compat/exp/issue8_1');

      dynamic lastKey;
      var macAddress = '00:0a:95:9d:68:16';
      await db.transaction((txn) async {
        // put twice the same record
        await txn.put({'macAddress': macAddress});
        lastKey = await txn.put({'macAddress': macAddress});
      });
      // Sorting by key requires using the special Field.key
      var finder = Finder(
          filter: Filter.equal('macAddress', macAddress),
          sortOrders: [SortOrder(Field.key, false)]);
      // finding one record automatically set limit to 1
      expect((await db.findRecord(finder)).key, lastKey);
    });

    test('issue8_2', () async {
      db = await setupForTest(ctx, 'compat/exp/issue8_2');
      var beaconsStoreName = 'beacons';
      dynamic key2, key3;
      await db.transaction((txn) async {
        var store = txn.getStore(beaconsStoreName);
        await store.put({'name': 'beacon1'});
        key2 = await store.put({'name': 'beacon2'});
        key3 = await store.put({'name': 'beacon3'});
      });

      var recordsIds = [key2, key3];
      await db.transaction((txn) async {
        var store = txn.getStore(beaconsStoreName);
        final futures = <Future>[];
        recordsIds.forEach(
            (key) => futures.add(store.update({'flushed': true}, key)));
        await Future.wait(futures);
      });

      var store = db.getStore(beaconsStoreName);
      var records = await store.findRecords(null);
      expect(getRecordsValues(records), [
        {'name': 'beacon1'},
        {'name': 'beacon2', 'flushed': true},
        {'name': 'beacon3', 'flushed': true}
      ]);
    });
  });
}
