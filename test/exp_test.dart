library sembast.exp_test;

// basically same as the io runner but with extra output
import 'package:sembast/sembast.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('exp', () {
    Database db;

    _tearDown() {
      if (db != null) {
        db.close();
        db = null;
      }
    }

    Store store;
    Record record1, record2, record3;
    setUp(() async {
      db = await setupForTest(ctx);
      store = db.mainStore;
      record1 = Record(store, "hi", 1);
      record2 = Record(store, "ho", 2);
      record3 = Record(store, "ha", 3);
      return db.putRecords([record1, record2, record3]);
    });

    tearDown(_tearDown);

    test('issue#8', () async {
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

    test('doc', () async {
      db = await setupForTest(ctx);

      // Store some objects
      await db.transaction((txn) async {
        await txn.put({'name': 'fish'});
        await txn.put({'name': 'cat'});
        await txn.put({'name': 'dog'});
      });

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
  });
}
