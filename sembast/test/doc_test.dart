library sembast.doc_test;

import 'package:sembast/src/api/sembast.dart';

import 'compat/doc_test.dart';
import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('doc', () {
    Database db;

    setUp(() async {});

    tearDown(() async {
      if (db != null) {
        await db.close();
        db = null;
      }
    });
    test('new_1.15 doc', () async {
      db = await setupForTest(ctx);

      {
        // Use the main store for storing key values as String
        var store = StoreRef<String, String>.main();

        // Writing the data
        await store.record('username').put(db, 'my_username');
        await store.record('url').put(db, 'my_url');

        // Reading the data
        var url = await store.record('url').get(db);
        var username = await store.record('username').get(db);

        await db.transaction((txn) async {
          url = await store.record('url').get(txn);
          username = await store.record('username').get(txn);
        });

        unused([url, username]);
      }

      {
        // Use the main store, key being an int, value a Map<String, dynamic>
        // Lint warnings will warn you if you try to use different types
        var store = intMapStoreFactory.store();
        var key = await store.add(db, {'offline': true});
        var value = await store.record(key).get(db);

        unused(value);
      }

      {
        // Use the animals store using Map records with int keys
        var store = intMapStoreFactory.store('animals');

        // Store some objects
        await db.transaction((txn) async {
          await store.add(txn, {'name': 'fish'});
          await store.add(txn, {'name': 'cat'});
          await store.add(txn, {'name': 'dog'});
        });

        // Look for any animal "greater than" (alphabetically) 'cat'
        // ordered by name
        var finder = Finder(
            filter: Filter.greaterThan('name', 'cat'),
            sortOrders: [SortOrder('name')]);
        var records = await store.find(db, finder: finder);

        expect(records.length, 2);
        expect(records[0]['name'], 'dog');
        expect(records[1]['name'], 'fish');
      }

      {
        var store = intMapStoreFactory.store('animals');
        await store.drop(db);

        // Store some objects
        int key1, key2, key3;
        await db.transaction((txn) async {
          key1 = await store.add(txn, {'name': 'fish'});
          key2 = await store.add(txn, {'name': 'cat'});
          key3 = await store.add(txn, {'name': 'dog'});
        });

        // Read by key
        expect(await store.record(key1).get(db), {'name': 'fish'});

// Read 2 records by key
        var records = await store.records([key2, key3]).get(db);
        expect(records[0], {'name': 'cat'});
        expect(records[1], {'name': 'dog'});

        {
          // Look for any animal "greater than" (alphabetically) 'cat'
          // ordered by name
          var finder = Finder(
              filter: Filter.greaterThan('name', 'cat'),
              sortOrders: [SortOrder('name')]);
          var records = await store.find(db, finder: finder);

          expect(records.length, 2);
          expect(records[0]['name'], 'dog');
          expect(records[1]['name'], 'fish');
        }
        {
          // Look for the last created record
          var finder = Finder(sortOrders: [SortOrder(Field.key, false)]);
          var record = await store.findFirst(db, finder: finder);

          expect(record['name'], 'dog');
        }
        {
          // Look for the one after `cat`
          var finder = Finder(
              sortOrders: [SortOrder('name', true)],
              start: Boundary(values: ['cat']));
          var record = await store.findFirst(db, finder: finder);
          expect(record['name'], 'dog');
        }
        {
          // Our shop store
          var store = intMapStoreFactory.store('shop');

          await db.transaction((txn) async {
            await store.add(txn, {'name': 'Lamp', 'price': 10});
            await store.add(txn, {'name': 'Chair', 'price': 10});
            await store.add(txn, {'name': 'Deco', 'price': 5});
            await store.add(txn, {'name': 'Table', 'price': 35});
          });

          // Look for object after Chair 10 (ordered by price then name) so
          // should the the Lamp 10
          var finder = Finder(
              sortOrders: [SortOrder('price'), SortOrder('name')],
              start: Boundary(values: [10, 'Chair']));
          var record = await store.findFirst(db, finder: finder);
          expect(record['name'], 'Lamp');

          // You can also specify to look after a given record
          finder = Finder(
              sortOrders: [SortOrder('price'), SortOrder('name')],
              start: Boundary(record: record));
          record = await store.findFirst(db, finder: finder);
          // After the lamp the more expensive one is the Table
          expect(record['name'], 'Table');
        }
      }
    });
  });
}
