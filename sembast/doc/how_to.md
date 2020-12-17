# How-to

See some [Usage recommendations](usage_recommendations.md).
## Unit test

Easiest is to use the `databaseFactoryMemory` to develop and test your database API.

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

## Flutter test testWidgets()

It seems File io write access is not possible in write mode during testWidgets without changes (try to create a directory, it won't work neither).
                                                     
What you could do during unittest is to use a different factory: `databaseFactoryMemory`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future main() async {
  testWidgets('database', (tester) async {
    var db = await databaseFactoryMemory.openDatabase('database');
    expect(db, isNotNull);
    await db.close();
  });
}
```

## Isolates

Sembast io database (single file in json format) should be used from the main isolate only.

* Sembast io (`databaseFactoryIo`) is not cross-isolate safe. Dataloss and corruption possible.
* Sembast io is not cross-process safe.
* [sembast_sqflite](https://pub.dev/packages/sembast_sqflite) factory is cross-process safe (more tests to be done regarding some locked access but data is not corrupted). sqflite itself should not be used from another isolage.
* [sembast_web](https://pub.dev/packages/sembast_web) factory is cross-tab safe. Relying on indexed DB, it should be cross-worker safe (no tests done in web workers yet)

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

## Convert int keys to String keys

Let's assume you have a simple database with 3 fruits with generated int ids.

```dart
var fruitStoreV1 = intMapStoreFactory.store('fruit');
var db = await factory.openDatabase('database.db', version: 1);
await fruitStoreV1.addAll(
  db,
  ['banana', 'apple', 'pear']
    .map((fruitName) => {'name': fruitName})
    .toList());
(await fruitStoreV1.find(db))
  .forEach((snapshot) => print('${snapshot.key}: ${snapshot.value}'));
// 1: {name: banana}
// 2: {name: apple}
// 3: {name: pear}
await db.close();
```

You could convert to String keys with something like this:

```dart
// New format, new store.
var fruitStoreV2 = stringMapStoreFactory.store('fruit_v2');
var fruitStore = fruitStoreV2;
// New version 2, key are string for fruit.
var db = await factory.openDatabase('database.db', version: 2,
    onVersionChanged: (db, oldVersion, newVersion) async {
  if (oldVersion == 1) {
    // Convert int key to String keys.
    await db.transaction((txn) async {
      // Convert int key to String key, by adding the existing to the new store
      await fruitStoreV2.addAll(
          txn,
          (await fruitStoreV1.find(txn))
              .map((snapshot) => snapshot.value)
      .toList());
      // Drop the old store
      await fruitStoreV1.drop(txn);
    });
  }
});
(await fruitStore.find(db))
    .forEach((snapshot) => print('${snapshot.key}: ${snapshot.value}'));
// -MNxE-uEQjljyvy8BCFl: {name: banana}
// -MNxE-uGfue6D7DJAFY2: {name: apple}
// -MNxE-uGfue6D7DJAFY3: {name: pear}
await db.close();
```

This is of course, the simplest scenario that might not fit your needs.
A more complex migration could be done. Any reference to the old key, if any, should be updated too.
If you don't want to change the store name, another step would be to move the data again to the old store.
