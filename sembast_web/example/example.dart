import 'package:sembast_web/sembast_web.dart';

/// True when compiled for the web (JavaScript or WebAssembly).
const isWeb = bool.fromEnvironment('dart.library.js_interop');

Future main() async {
  if (!isWeb) {
    print('This example is for the web only');
    return;
  }
  // Declare our store (records are maps, ids are ints)
  var store = intMapStoreFactory.store();
  var factory = databaseFactoryWeb;

  // Open the database: the name of the IndexedDB database, not a file path.
  var db = await factory.openDatabase('test');

  // Add a new record
  var key = await store.add(db, <String, Object?>{
    'name': 'Table',
    'price': 15,
  });

  // Read the record
  var value = await store.record(key).get(db);

  // Print the value
  print(value);

  // Close the database
  await db.close();
}
