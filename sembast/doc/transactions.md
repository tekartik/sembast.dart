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

// Without transaction
expect(await store.delete(db, finder: Finder(filter: Filter.equals('age', 5))), 2);
expect(await store.records([key1, key2, key3]).get(db), [
  null,
  {'name': 'cat'},
  null
]);

// Delete in a transaction
await db.transaction((txn) async {
  expect(await store.delete(txn, finder: Finder(filter: Filter.equals('age', 5))), 2);
});

```

## When to use transaction

Write operations should be grouped in transactions for consistency and performance You can read/add/delete/update/write in the same transaction.

```dart
// Let's assume a store with the following products
var store = intMapStoreFactory.store('product');
await store.addAll(db, [
  {'name': 'Lamp', 'price': 10, 'id': 'lamp'},
  {'name': 'Chair', 'price': 100, 'id': 'chair'},
  {'name': 'Table', 'price': 250, 'id': 'table'}
]);
```

Let's assume you want a function to update all of your products

```dart
await updateProducts(
  [
    {'name': 'Lamp', 'price': 17, 'id': 'lamp'},    // Price modified
    {'name': 'Bike', 'price': 999, 'id': 'bike'},   // Added
    {'name': 'Chair', 'price': 100, 'id': 'chair'}, // Unchanged
                                                    // Product 'table' had been removed           
  ],
);
```

A first basic implementation would be (but could be improved
as in fact 2 transactions are created here)

```dart
// Update without using transactions
Future<void> updateProducts(
  List<Map<String, Object?>> products) async {
  // Delete all existing products first.
  // One transaction is created here
  await store.delete(db);
  // Add all products
  // One transaction is created here
  await store.addAll(db, products);
}
```

A small improvment would be to use a transaction:

```dart
// Update in a transaction
Future<void> updateProducts(
    List<Map<String, Object?>> products) async {
  await db.transaction((transaction) async {
    // Delete all
    await store.delete(transaction);
    // Add all
    await store.addAll(transaction, products);
  });
}
```

However we are still deleting everything first, so even if a product
does not change, a write is performed.

A better optimized version would check for deleted/updated/added items
to only perform the necessary writes:

```dart
/// Read products by ids and return a map
Future<Map<String, RecordSnapshot<int, Map<String, Object?>>>>
getProductsByIds(DatabaseClient db, List<String> ids) async {
  var snapshots = await store.find(db,
      finder: Finder(
          filter: Filter.or(
              ids.map((e) => Filter.equals('id', e)).toList())));
  return <String, RecordSnapshot<int, Map<String, Object?>>>{
    for (var snapshot in snapshots)
      snapshot.value['id']!.toString(): snapshot
  };
}

/// Update products
/// 
/// - Unmodified records remain untouched
/// - Modified records are updated
/// - New records are added.
/// - Missing one are deleted
Future<void> updateProducts(
    List<Map<String, Object?>> products) async {
  await db.transaction((transaction) async {
    var productIds =
    products.map((map) => map['id'] as String).toList();
    var map = await getProductsByIds(db, productIds);
    // Watch for deleted item
    var keysToDelete = (await store.findKeys(transaction)).toList();
    for (var product in products) {
      var snapshot = map[product['id'] as String];
      if (snapshot != null) {
        // The record current key
        var key = snapshot.key;
        // Remove from deletion list
        keysToDelete.remove(key);
        // Don't update if no change
        if (const DeepCollectionEquality()
            .equals(snapshot.value, product)) {
          // no changes
          continue;
        } else {
          // Update product
          await store.record(key).put(transaction, product);
        }
      } else {
        // Add missing product
        await store.add(transaction, product);
      }
    }
    // Delete the one not present any more
    await store.records(keysToDelete).delete(transaction);
  });
}
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
