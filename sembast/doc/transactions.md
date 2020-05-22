# Transactions

## Execute

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

Example on how to find and update in a transaction

```dart
// Filter for updating records
var finder = Finder(filter: Filter.greaterThan('name', 'cat'));

// Update without transaction
await store.update(db, {'age': 4}, finder: finder);
expect(await store.records([key1, key2, key3]).get(db), [
  {'name': 'fish', 'age': 4},
  {'name': 'cat'},
  {'name': 'dog', 'age': 4}
]);

// Update within transaction (not necessary, update is already done in
// a transaction
await db.transaction((txn) async {
  expect(await store.update(txn, {'age': 5}, finder: finder), 2);
});
expect(await store.records([key1, key2, key3]).get(db), [
  {'name': 'fish', 'age': 5},
  {'name': 'cat'},
  {'name': 'dog', 'age': 5}
]);

expect(await store.delete(db, finder: Finder(filter: Filter.equals('age', 5))), 2);
expect(await store.records([key1, key2, key3]).get(db), [
  null,
  {'name': 'cat'},
  null
]);

```

## Dead lock

It is important to use the transaction object and not the database in a transaction.
The following code will deadlock:

```dart
await db.transaction((txn) async {
  // !Wrong the following code will deadlock
  // Don't use the db object in the transaction
  await record.put(db, {'name': 'fish'});
});
```

Correct form would be:

```dart
await db.transaction((txn) async {
  // correct, txn in used
  await record.put(txn, {'name': 'fish'});
});
```
