## Migration example

sembast is schema less so there is not much you have to specify when opening/upgrading a database.
There is however a lightweight versioning system.

### Database creation

By default, unless specified a new database has version 1
after being opened. While this value seems odd, it actually enforces
migration during `onVersionChanged`

```dart
await factory.deleteDatabase(path);
var db = await factory.openDatabase(path);
expect(db.version, 1);
await db.close();
```

Handling creation can be safely done in `onVersionChanged`.

```dart
// It has version 0 if created in onVersionChanged
await factory.deleteDatabase(path);
db = await factory.openDatabase(path, version: 1,
  onVersionChanged: (db, oldVersion, newVersion) async {
    expect(oldVersion, 0);
    expect(newVersion, 1);
});
expect(db.version, 1);
await db.close();
```

### Database migration/update

Let's define some schema information.

```dart
// You can perform basic data migration, by specifying a version
var store = stringMapStoreFactory.store('product');
var demoProductRecord1 = store.record('demo_product_1');
var demoProductRecord2 = store.record('demo_product_2');
var demoProductRecord3 = store.record('demo_product_3');
```

1st Version. We want to create 2 demo product with a fixed key.

```dart
await factory.deleteDatabase(path);
db = await factory.openDatabase(path, version: 1,
  onVersionChanged: (db, oldVersion, newVersion) async {
    // If the db does not exist, create some data
    if (oldVersion == 0) {
      await demoProductRecord1
        .put(db, {'name': 'Demo product 1', 'price': 10});
      await demoProductRecord2
        .put(db, {'name': 'Demo product 2', 'price': 100});
    }
  });
```

Let's see our content after opening:

```dart
Future<List<Map<String, Object?>>> getProductMaps() async {
  var results = await store
    .stream(db)
    .map((snapshot) => Map<String, Object?>.from(snapshot.value)
       ..['id'] = snapshot.key)
    .toList();
  return results;
}

expect(await getProductMaps(), [
  {'name': 'Demo product 1', 'price': 10, 'id': 'demo_product_1'},
  {'name': 'Demo product 2', 'price': 100, 'id': 'demo_product_2'}
]);
await db.close();
```

Let's deploy a new version of our app, handling existing data by
updating a price.

```dart
// You can perform update migration, by specifying a new version
// Here in version 2, we want to update the price of a demo product
db = await factory.openDatabase(path, version: 2,
  onVersionChanged: (db, oldVersion, newVersion) async {
    if (oldVersion < 2) {
    // Creation 0 -> 1
    // Migration 1 -> 2
    await demoProductRecord1
        .put(db, {'name': 'Demo product 1', 'price': 15});
    }
    
    // Creation 0 -> 1
    if (oldVersion < 1) {
    await demoProductRecord2
        .put(db, {'name': 'Demo product 2', 'price': 100});
    } else if (oldVersion < 2) {
    // Migration 1 -> 2
    // no action needed.
  }
});
expect(await getProductMaps(), [
  {'name': 'Demo product 1', 'price': 15, 'id': 'demo_product_1'},
  {'name': 'Demo product 2', 'price': 100, 'id': 'demo_product_2'}
]);
```

Add a new demo product from your application.
```dart
// Let's add a new demo product
await demoProductRecord3
    .put(db, {'name': 'Demo product 3', 'price': 1000});
await db.close();
```

Let's deploy a new version. We used to have demo in the name of our demo
product, let's change that to use a tag instead for all demo products
going forward.

```dart
// Let say you want to tag your existing demo product as demo by adding
// a tag propery
db = await factory.openDatabase(path, version: 3,
  onVersionChanged: (db, oldVersion, newVersion) async {
    if (oldVersion < 3) {
      // Creation
      await demoProductRecord1.put(
        db, {'name': 'Demo product 1', 'price': 15, 'tag': 'demo'});
    }
    
    // Creation 0 -> 1
    if (oldVersion < 1) {
      await demoProductRecord2.put(
        db, {'name': 'Demo product 2', 'price': 100, 'tag': 'demo'});
    } else if (oldVersion < 3) {
      // Migration 1 -> 3
      // Add demo tag to all records containing 'demo' in their name
      // no action needed.
      await store.update(db, {'tag': 'demo'},
        finder: Finder(
        filter: Filter.custom((record) => (record['name'] as String)
          .toLowerCase()
          .contains('demo'))));
  }
});
expect(await getProductMaps(), [
  {
    'name': 'Demo product 1',
    'price': 15,
    'tag': 'demo',
    'id': 'demo_product_1'
  },
  {
    'name': 'Demo product 2',
    'price': 100,
    'tag': 'demo',
    'id': 'demo_product_2'
  },
  {
    'name': 'Demo product 3',
    'price': 1000,
    'tag': 'demo',
    'id': 'demo_product_3'
  }
]);
```

## Migrate to/from an encrypted database

This is a different migration mechanism as here the storage format will change. Basically it means
using a different codec (or null for non-encrypted database).

Since the codec has to be specified at creation time, you cannot change your codec later.

One solution is export the existing database and import it in a new database. Below is a simple
example converting a non-encrypted database to an encrypted one.

```dart
// Open my existing database and close it
db = await factory.openDatabase('my_existing.db');
var exportMap = await exportDatabase(db);
await db.close();

// Import the existing export in a newly created database using encryption
db = await importDatabase(exportMap, factory, 'my_encrypted.db',
    codec: codec);

// The new database is now encrypted, you can deleted the old one and you must
// always use the same codec to open the new one.
```