# Transactions

## Execute

Actions can be grouped in transaction for consistency and efficiency.
Changes are visible, only in the transaction when not commited and for every readers when commited

```dart
await db.transaction((txn) async {
  var store = txn.getStore('animals');
  key1 = await store.put({'name': 'fish'});
  key2 = await store.put({'name': 'cat'});
  key3 = await store.put({'name': 'dog'});
});
```

Example on how to find and update in a transaction

```dart
///
/// Update all records matching [where] with the [values] fields
/// Returns the number of records updated
///
Future<int> updateRecords(sembastStore executor, Map<String, dynamic> values,
    {Finder where}) async {
  var records = await executor.findRecords(where);
  for (var record in records) {
    await executor.update(values, record.key);
  }
  return records.length;
}

await db.transaction((txn) async {
  var finder = Finder(filter: Filter.greaterThan('name', 'cat'));
  var store = txn.getStore('animals');
  int count = await updateRecords(store, {'age': 5}, where: finder);
  expect(count, 2);

  // Only fish and dog are modified
  expect(getRecordsValues(await store.getRecords([key1, key2, key3])), [
    {'name': 'fish', 'age': 5},
    {'name': 'cat'},
    {'name': 'dog', 'age': 5}
  ]);
});

```

## Dead lock

### Database dead lock

The following code will deadlock

```dart
await db.transaction((txn) async {
  // !Wrong the following code will deadlock
  // Don't use the db object in the transaction
  await db.put({'name': 'fish'});
});
```

Correct form would be:

```dart
await db.transaction((txn) async {
  // correct, txn in used
  await txn.put({'name': 'fish'});
});
```

### Transaction dead lock

The following code will deadlock

```dart
var store = db.getStore('animals');
await db.transaction((txn) async {
  // !Wrong the following code will deadlock
  await store.put({'name': 'fish'});
});
```

Correct form would be:

```dart

await db.transaction((txn) async {
  // correct store got in the transaction
  var store = txn.getStore('animals');
  await store.put({'name': 'fish'});
});
```