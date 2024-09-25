import 'package:sembast_web/sembast_web.dart';

Future main() async {
  // Declare our store (records are mapd, ids are ints)
  var store = intMapStoreFactory.store();
  var factory = databaseFactoryWeb;

  // Open the database
  var db = await factory.openDatabase('test');

  // Add a new record
  var key =
      await store.add(db, <String, Object?>{'name': 'Table', 'price': 15});

  // Read the record
  var value = await store.record(key).get(db);

  // Print the value
  print(value);

  // Close the database
  await db.close();
}
