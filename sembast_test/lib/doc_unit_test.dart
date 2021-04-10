import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  test('my_unit_test', () async {
    // In memory factory for unit test
    var factory = newDatabaseFactoryMemory();

    // Define the store
    var store = StoreRef<String, String>.main();
    // Define the record
    var record = store.record('my_key');

    // Open the database
    var db = await factory.openDatabase('test.db');

    // Write a record
    await record.put(db, 'my_value');

    // Verify record content.
    expect(await record.get(db), 'my_value');

    // Close the database
    await db.close();
  });
}
