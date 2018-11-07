library sembast.exp_test;

import 'dart:async';

import 'package:sembast/sembast.dart';
import 'package:sembast/utils/database_utils.dart';
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
      db = await setupForTest(ctx);

      dynamic lastKey;
      var macAddress = '00:0a:95:9d:68:16';
      await db.transaction((txn) async {
        // put twice the same record
        txn.put({'macAddress': macAddress});
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
      db = await setupForTest(ctx);
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
        List<Future> futures = [];
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

    test('queries_doc', () async {
      db = await setupForTest(ctx);

      // Store some objects
      dynamic key1, key2, key3;
      await db.transaction((txn) async {
        key1 = await txn.put({'name': 'fish'});
        key2 = await txn.put({'name': 'cat'});
        key3 = await txn.put({'name': 'dog'});
      });

      {
        // Read by key
        expect(await db.get(key1), {'name': 'fish'});

        // Read 2 records by key
        var records = await db.getRecords([key2, key3]);
        expect(records[0].value, {'name': 'cat'});
        expect(records[1].value, {'name': 'dog'});
      }

      // Look for any animal "greater than" (alphabetically) 'cat'
      // ordered by name
      var finder = Finder(
          filter: Filter.greaterThan('name', 'cat'),
          sortOrders: [SortOrder('name')]);
      var records = await db.findRecords(finder);

      expect(records.length, 2);
      expect(records[0]['name'], 'dog');
      expect(records[1]['name'], 'fish');

      // Look for the last created record
      {
        var finder = Finder(sortOrders: [SortOrder(Field.key, false)]);
        var record = await db.findRecord(finder);

        expect(record['name'], 'dog');
      }
    });

    test('writes_doc', () async {
      db = await setupForTest(ctx);

      {
        // Writing a string
        var key = await db.put('value');
        expect(await db.get(key), 'value');

        // Updating a string
        await db.put('new value', key);
        expect(await db.get(key), 'new value');
      }

      {
        // Writing a map
        var key = await db.put({
          'name': 'cat',
          'color': 'brown',
          'age': 4,
          'address': {'city': 'Ledignan'}
        });

        // Updating some fields
        await db.update(
            {'color': FieldValue.delete, 'address.city': 'San Francisco'}, key);
        expect(await db.get(key), {
          'name': 'cat',
          'age': 4,
          'address': {'city': 'San Francisco'}
        });
      }
    });

    test('transaction_writes_doc', () async {
      db = await setupForTest(ctx);

      // Store some objects
      dynamic key1, key2, key3;
      await db.transaction((txn) async {
        var store = txn.getStore('animals');
        key1 = await store.put({'name': 'fish'});
        key2 = await store.put({'name': 'cat'});
        key3 = await store.put({'name': 'dog'});
      });

      {
        // Read by key
        var store = db.getStore('animals');
        expect(await store.get(key1), {'name': 'fish'});

        // Read 2 records by key
        var records = await store.getRecords([key2, key3]);
        expect(records[0].value, {'name': 'cat'});
        expect(records[1].value, {'name': 'dog'});
      }

      {
        var store = db.getStore('animals');
        // Look for any animal "greater than" (alphabetically) 'cat'
        // ordered by name
        var finder = Finder(
            filter: Filter.greaterThan('name', 'cat'),
            sortOrders: [SortOrder('name')]);
        var records = await store.findRecords(finder);

        expect(records.length, 2);
        expect(records[0]['name'], 'dog');
        expect(records[1]['name'], 'fish');

        // Look for the last created record
        {
          var finder = Finder(sortOrders: [SortOrder(Field.key, false)]);
          var record = await store.findRecord(finder);

          expect(record['name'], 'dog');
        }

        // Updates with request
        await db.transaction((txn) async {
          var finder = Finder(filter: Filter.greaterThan('name', 'cat'));
          var store = txn.getStore('animals');
          var records = await store.findRecords(finder);
          expect(records.length, 2);
          for (var record in records) {
            await store.update({'age': 4}, record.key);
          }
        });
        expect(getRecordsValues(await store.getRecords([key1, key2, key3])), [
          {'name': 'fish', 'age': 4},
          {'name': 'cat'},
          {'name': 'dog', 'age': 4}
        ]);

        await db.transaction((txn) async {
          var finder = Finder(filter: Filter.greaterThan('name', 'cat'));
          var store = txn.getStore('animals');
          int count = await updateRecords(store, {'age': 5}, where: finder);
          expect(count, 2);

          // Only fish and dog are modified
          expect(getRecordsValues(await store.getRecords([key1, key2, key3])), [
            {'name': 'fish', 'age': 5},
            {'name': 'cat'},
            {'name': 'dog', 'age': 5}
          ]);
        });
      }
    });
  });
}
