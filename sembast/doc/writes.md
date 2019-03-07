# Writing data

## Use transactions

Make sure to use transaction as soon as you perform more than 1 writes. It 
will greatly improve performances. See information on transaction [here](transactions.md)

The code below use the Database object `db` but the same can be done with a
`Store` or `Transaction` object

## Writing raw data on the main store

You can add a simple data using `put`. Here the key is generated 
(auto-incremented int)

```dart
var key = await db.put('value');
expect(await db.get(key), 'value');
```

`put` can also ne used to update data

```dart
// Updating a string
await db.put('new value', key);
expect(await db.get(key), 'new value');
```

## Updating fields

A record value in an application is typically a map that can be written like 
this:

```dart
// Writing a map
var key = await db.put({
  'name': 'Felix',
  'age': 4,
  'address': {'city': 'Ledignan'}
});
```

If you want to only update some fields you can use the following semantics
similar to `firestore.set` where fields can be deleted, updated and addressed
using the `a.b.c` form instead of `'a':{'b':{'c'}}`


```dart
 // Updating some fields
await db.update(
  {'color': FieldValue.delete, 'address.city': 'San Francisco'}, key);
expect(await db.get(key), {
  'name': 'cat',
  'age': 4,
  'address': {'city': 'San Francisco'}
});
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
