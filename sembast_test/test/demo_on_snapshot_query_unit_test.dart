// Example on how to perform a complex unit test with Sembast.
import 'dart:async';

import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  late Database db;
  setUp(() async {
    /// Open the database (use memory)
    var factory = databaseFactoryMemory;
    db = await factory.openDatabase(sembastInMemoryDatabasePath);
  });
  tearDown(() async {
    await db.close();
  });
  test('onSnapshot', () async {
    // Current records
    late List<RecordSnapshot> currentQueryRecords;

    // Key is an int, value is a map
    var store = intMapStoreFactory.store();

    // Create a query to test records with 'key1' = 'value1'
    // Ordered by keys
    var query = store.query(
      finder: Finder(
        filter: Filter.equals('key1', 'value1'),
        sortOrders: [SortOrder(Field.key)],
      ),
    );

    // Add some data
    await db.transaction((txn) async {
      // matches
      await store.record(1).put(txn, {'key1': 'value1'});
      // does not match
      await store.record(2).put(txn, {'key1': 'value2'});
      // matches
      await store.record(3).put(txn, {'key1': 'value1'});
    });

    // create test completers when we have 2 records
    var count2Completer = Completer<void>();
    // create test completers when we have 3 records
    var count3Completer = Completer<void>();

    /// Listen to the query snapshots
    var subscription = query.onSnapshots(db).listen((records) {
      // For debugging purpose
      print('records $records');
      currentQueryRecords = records;
      if (records.length == 2 && !count2Completer.isCompleted) {
        count2Completer.complete();
      } else if (records.length == 3 && !count3Completer.isCompleted) {
        count3Completer.complete();
      }
    });

    // Wait for the first 2 records
    await count2Completer.future;
    // Record 1 and 3 matches
    expect(currentQueryRecords.map((snapshot) => snapshot.key), [1, 3]);

    // Modify 3 records, modify record 2 to match, delete record 3, add record 4
    // 3 rcords should match then
    await db.transaction((txn) async {
      // matches
      await store.record(2).put(txn, {'key1': 'value1'});
      // matches
      await store.record(3).delete(txn);
      // matches
      await store.record(4).put(txn, {'key1': 'value1'});
    });

    // Wait for the query to match 3 records
    await count3Completer.future;
    // Record 1, 2 and 4 matches
    expect(currentQueryRecords.map((snapshot) => snapshot.key), [1, 2, 4]);
    await subscription.cancel();
    await db.close();
  });
}
