# How-to

## Unit test

Easiest is to use the `databaseFactoryInMemory` to develop and test your database API.

Simple unit test:
```dart
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  test('my_unit_test', () async {
    // In memory factory for unit test
    var factory = databaseFactoryMemory;

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
```
## Get the list of stores

Response: **you cannot**

A store only exists when they are records in it 
(there is no way to create/delete a store). There used to be a `storeNames` method
but there were some cases where a store could be listed even though it did not 
exist so the behavior was not consistent. The analogy is the collection 
in firestore (and you cannot list collections in firestore neither - although that is changing).

You might wonder what `StoreRef.drop` does. It only forces deleting the store from memory so that it is not
used in any further operations (until a record is added in this same store). 
 
So there is no safe way to get a list of stores and I would recommend storing a list of store names in a singleton that 
you track manually.