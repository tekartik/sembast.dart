library sembast.exp_test;

import 'package:sembast/sembast.dart';
import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('exp', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx);
    });

    tearDown(() async {
      if (db != null) {
        await db.close();
        db = null;
      }
    });

    Store store;
    Record record1, record2, record3;
    setUp(() async {
      store = db.mainStore;
      record1 = Record(store, "hi", 1);
      record2 = Record(store, "ho", 2);
      record3 = Record(store, "ha", 3);
      return db.putRecords([record1, record2, record3]);
    });

    test('issue#8', () async {
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
  });
}
