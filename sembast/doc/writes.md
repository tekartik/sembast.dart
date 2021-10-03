# Writing data

## add vs update vs put

- `add` adds a new record and generate a new record key
- `update` update an existing record
- `put` will either create a new record with a user specified key or update a record

## Use transactions

Make sure to use transaction as soon as you perform more than 1 writes. It 
will greatly improve performances. See information on transaction [here](transactions.md)

The code below use the Database object `db` but the same can be done with a
`Store` or `Transaction` object

## Adding data

### Using auto-generated int key

Add some data:

```dart
// Use the main store for storing map data with an auto-generated
// int key
var store = intMapStoreFactory.store();

// Add the data and get its new generated key
var key = await store.add(db, {'value': 'test'});

// Retrieve the record
var record = store.record(key);
var readMap = await record.get(db);

expect(readMap, {'value': 'test'});
```

### Specify the added key

You can also specify the key of the added record if you don't want to have an auto-generated one.
Add will fail if the record already exists.

```dart
// Add the data with a specified key (1234).
// Fails if the record already exists
await store.record(1234).add(db, {'value': 'test'});
```

## Update data

You can update the data of a given record using put or update (update will fail if the record does not exist):

```dart
 // Update the record
await record.put(db, {'other_value': 'test2'}, merge: true);

readMap = await record.get(db);

expect(readMap, {'value': 'test', 'other_value': 'test2'});
```

## Updating fields

A record value in an application is typically a map that can be written like 
this:

```dart
// Writing a map
var key = await store.add(db, {
  'name': 'Felix',
  'age': 4,
  'address': {'city': 'Ledignan'}
});
```

If you want to only update some fields you can use the following semantics
similar to `firestore.set` where fields can be deleted, updated and addressed
using the `a.b.c` form instead of `'a':{'b':{'c'}}`


```dart
var record = store.record(key);
 // Updating some fields
await record.update(db,
  {'color': FieldValue.delete, 'address.city': 'San Francisco'});
expect(await record.get(db), {
  'name': 'Felix',
  'age': 4,
  'address': {'city': 'San Francisco'}
});
```

Dots (`.`) are treated as separator for `record.update` calls (not `store.add` and `record.set`). To allow for keys with dot, you
can escape them using `FieldKey.escape` 

```dart
await record.update(db, {FieldKey.escape('my.color'): 'red'});
```

## Delete records

You can delete a single record by key using the `RecordRef.delete` method.

```dart
// Record by key.
var record = store.record(key);
// Delete the record.
await record.delete(db);
```

You can delete one or multiple records using the `StoreRef.delete` method.

```dart
// Delete all records with a price greater then 10
var filter = Filter.greaterThan('price', 10);
var finder = Finder(filter: filter);
await store.delete(db, finder: finder);
```

You can also clear the whole store:

```dart
// Clear all records from the store
await store.delete(db);
```

## Write example

Let's insert/update some data:

```dart
// Our shop store sample data
var store = intMapStoreFactory.store('shop');

int lampKey;
int chairKey;
await db.transaction((txn) async {
  // Add 2 records
  lampKey = await store.add(txn, {'name': 'Lamp', 'price': 10});
  chairKey = await store.add(txn, {'name': 'Chair', 'price': 15});
});

// update the price of the lamp record
await store.record(lampKey).update(db, {'price': 12});
```

## Bulk update

`updateRecords` is a utility function that can work with or without transaction to update fields in multiple records

```dart
// Filter for updating records
var finder = Finder(filter: Filter.greaterThan('name', 'cat'));

// Update without transaction
var store = db.getStore('animals');
await updateRecords(store, {'age': 4}, where: finder);

// Update within transaction
await db.transaction((txn) async {
  var store = txn.getStore('animals');
  await updateRecords(store, {'age': 5}, where: finder);
});
```

## Add or update example

Let's assume a product store where the unique key is an integer.
But you want to have a unique 'code' field (each product having a unique code).
(Although as a side note, it is more clever to use the code as a string key)

```dart
var store = intMapStoreFactory.store('product');

// Add some data
await db.transaction((txn) async {
  await store.add(txn, {'code': '001', 'name': 'Lamp', 'price': 10});
  await store.add(txn, {'code': '002', 'name': 'Chair', 'price': 25});
});
```

Let's write a function that will either add or update a record. To handle
race conditions and avoid duplicates, this must be done in a transaction:

```dart
/// Either add or modify records with a given 'code'
Future<void> addOrUpdateProduct(Map<String, Object?> map) async {
  // Check if the record exists before adding or updating it.
  await db.transaction((txn) async {
    // Look of existing record
    var existing = await store
        .query(
            finder:
                Finder(filter: Filter.equals('code', map['code'])))
        .getSnapshot(txn);
    if (existing == null) {
      // code not found, add
      await store.add(txn, map);
    } else {
      // Update existing
      await existing.ref.update(txn, map);
    }
  });
}
```

Quick test:

```dart
// Update existing
await addOrUpdateProduct(
    {'code': '002', 'name': 'Chair', 'price': 35});
// Add new
await addOrUpdateProduct(
    {'code': '003', 'name': 'Table', 'price': 82});

// Should print:
// {code: 001, name: Lamp, price: 10}
// {code: 002, name: Chair, price: 35} - Updated
// {code: 003, name: Table, price: 82}
for (var snapshot in await store.query().getSnapshots(db)) {
  print(snapshot.value);
}
```