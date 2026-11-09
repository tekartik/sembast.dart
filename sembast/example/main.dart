// Minimal sembast example for the Dart VM (open, write, read, find, close).
//
// Flutter apps use the same API with a path from path_provider, see the
// README. Web apps use databaseFactoryWeb from package:sembast_web.
import 'package:sembast/sembast_io.dart';

Future<void> main() async {
  // Open the database: a file path, relative to the current directory here.
  // The file and its folder are created if needed.
  var db = await databaseFactoryIo.openDatabase('.local/my_app.db');

  // A store with int keys and map values.
  var store = intMapStoreFactory.store('animals');

  // add generates the key, put writes the record of a given key.
  var catKey = await store.add(db, {'name': 'cat', 'age': 4});
  await store.record(100).put(db, {'name': 'dog', 'age': 7});

  // Read a record by key.
  var cat = await store.record(catKey).get(db);
  print(cat); // {name: cat, age: 4}

  // Find records: filter and sort.
  var finder = Finder(
    filter: Filter.greaterThan('age', 5),
    sortOrders: [SortOrder('name')],
  );
  var snapshots = await store.find(db, finder: finder);
  for (var snapshot in snapshots) {
    print('${snapshot.key}: ${snapshot.value}'); // 100: {name: dog, age: 7}
  }

  // Update some fields, delete a record.
  await store.record(catKey).update(db, {'age': 5});
  await store.record(100).delete(db);

  // Group writes in a transaction, use txn (not db) inside.
  await db.transaction((txn) async {
    await store.add(txn, {'name': 'fish'});
    await store.add(txn, {'name': 'bird'});
  });

  // Close it when done (end of a script or a test).
  await db.close();
}
