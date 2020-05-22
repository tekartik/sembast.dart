## Write data

Sembase uses `store` similar to firestore collection or at some level to sqlite table (without enforced schema).
You don't create or delete a store, you simply insert object into a store.

A store is defined by its key and value type to enforce strong mode. A typically usage would be an auto-generated
integer id and a Map containing the data as its value.

Below is the base for writing initial data. More information on writing data [here](writes.md).

First declare globally you store meta definition:

```dart
// Our product store.
var store = intMapStoreFactory.store('product');
```

### Add data

Then you can add data to your store:

```dart
int lampKey;
int chairKey;
await db.transaction((txn) async {
  // Add 2 records
  lampKey = await store.add(txn, {'name': 'Lamp', 'price': 10});
  chairKey = await store.add(txn, {'name': 'Chair', 'price': 15});
});
```

### Update data

Fastest access is using the key. A record reference can be created using `store.record(key)` that you can use to update
data.

An element is updated only if it exists.

```
// update the price of the lamp record
await store.record(lampKey).update(db, {'price': 12});
```

### Upsert data

The element will be either update or created.

```dart
var tableKey = 1000578;
// Update or create the table product with key 1000578
await store.record(tableKey).put(db, {'name': 'Table', 'price': 120});
```

### Using transaction

Actions can be grouped in transaction for consistency and efficiency.
Changes are visible, only in the transaction when not commited and for every readers when commited

```dart
var store = intMapStoreFactory.store('animals');
// Store some objects
int key1, key2, key3;
await db.transaction((txn) async {
  key1 = await store.add(txn, {'name': 'fish'});
  key2 = await store.add(txn, {'name': 'cat'});
  key3 = await store.add(txn, {'name': 'dog'});
});
```

More info [here](transactions.md) 

## Read data

### Get by key

You can get a record by key

```dart
// Read by key
expect(await store.record(lampKey).get(db), {'name': 'Lamp', 'price': 10});
```

More information on advances queries [here](queries.md).