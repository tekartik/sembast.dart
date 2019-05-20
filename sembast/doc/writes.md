# Writing data

## Use transactions

Make sure to use transaction as soon as you perform more than 1 writes. It 
will greatly improve performances. See information on transaction [here](transactions.md)

The code below use the Database object `db` but the same can be done with a
`Store` or `Transaction` object

## Writing data on the main store

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

Update data:

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

You can delete one or multiple records using the store `delete` method.

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
