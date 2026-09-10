---
name: sembast-crud
description: >-
  Use when writing Dart or Flutter code that stores, reads, updates or deletes
  records with package:sembast: StoreRef, intMapStoreFactory,
  stringMapStoreFactory, RecordRef, RecordsRef, add/put/update/get/delete,
  merge and FieldValue.delete, dotted field paths, db.transaction and the
  Transaction/DatabaseClient parameter, supported value types (Timestamp, Blob,
  immutable read values, cloneMap) and store change triggers
  (addOnChangesListener). Opening databases and queries have their own skills.
---

# sembast: stores, records, writes and transactions

`package:sembast` is a NoSQL document database (pure Dart, VM, Flutter and,
with `sembast_web`, the web). Data lives in typed stores of records. A
`StoreRef<K, V>` and a `RecordRef<K, V>` are immutable pointers, they hold no
data; every data method takes a `DatabaseClient` (the `Database` or a
`Transaction`) as first argument.

```dart
import 'package:sembast/sembast.dart';

// Declare stores once, globally. Keys are int, values are maps.
final productStore = intMapStoreFactory.store('product');

Future<void> demo(Database db) async {
  var key = await productStore.add(db, {'name': 'Lamp', 'price': 10});
  await productStore.record(key).update(db, {'price': 12});
  var value = await productStore.record(key).get(db);
  print(value); // {name: Lamp, price: 12}
  await productStore.record(key).delete(db);
}
```

## Guidelines

### Stores and references

* Import `package:sembast/sembast.dart`. It exports `StoreRef`, `RecordRef`,
  `RecordsRef`, `Database`, `Transaction`, `DatabaseClient`, `Field`,
  `FieldValue`, `FieldKey` and the extension methods (`add`, `put`, `get`...)
  on the refs. `sembast_io.dart` and `sembast_memory.dart` re-export it.
* Use `intMapStoreFactory.store('name')` for
  `StoreRef<int, Map<String, Object?>>` (auto-increment int keys) and
  `stringMapStoreFactory.store('name')` for
  `StoreRef<String, Map<String, Object?>>` (generated unique string keys).
  Omit the name (`intMapStoreFactory.store()`) for the main store.
* For other value types use `StoreRef<K, V>('name')` or
  `StoreRef<K, V>.main()`, for example `StoreRef<String, String>.main()` for
  key/value settings. `K` must be `int` or `String`, nothing else.
* Store names must not start with `_`. A store exists only while it has
  records; there is no create/delete store call. `store.drop(db)` deletes all
  its records, `db.dropAll()` (extension on `DatabaseClient`) clears the whole
  database.
* Declare stores and fixed records as top-level `final` variables and reuse
  them; `store.record(key)` and `store.records(keys)` are cheap.
* `RecordsRef` (from `store.records([k1, k2])` or
  `store.recordsFromRefs(refs)`) batches operations on known keys: `get`,
  `getSnapshots`, `add`, `put`, `update`, `delete`, `onSnapshots`, plus
  `length`, `refs` and `[index]`.

### Writing

* `store.add(db, value)` inserts with a generated key and returns it.
  `store.addAll(db, values)` returns the list of keys in one transaction.
  `record.add(db, value)` inserts with the record's key and returns `null`
  when the record already exists (nothing is written).
* `record.put(db, value)` creates or replaces (upsert) and returns the stored
  value. `put(..., merge: true)` merges a map into the existing map.
  `put(..., ifNotExists: true)` writes only when absent and returns the
  existing value otherwise. `merge` and `ifNotExists` cannot both be true.
* `record.update(db, value)` merges into an existing record and returns the
  new value, or `null` when the record does not exist (nothing is created).
  `store.update(db, value, finder: finder)` merges the same value into every
  matching record and returns the count (all records when `finder` is null).
* In `update` (and `put(merge: true)`) map keys are paths: `'address.city'`
  targets the nested `city` field. Set a field to `FieldValue.delete` to
  remove it. Use `FieldKey.escape('with.dots')` for a literal key containing
  a dot. `add` and plain `put` store keys verbatim, no path interpretation.
* `record.delete(db)` returns the key or `null` if absent.
  `store.delete(db, finder: finder)` deletes matching records and returns the
  count; without a finder it clears the store. `records.delete(db)` deletes a
  batch.
* Need a key before inserting? `store.generateKey(db)` (typed `K`) or
  `store.generateIntKey(db)`.

### Values

* Supported value types: `String`, `int`, `double`, `bool`, `null` (inside
  maps and lists only), `Map<String, Object?>`, `List<Object?>`, `Timestamp`
  (`package:sembast/timestamp.dart`) and `Blob`
  (`package:sembast/blob.dart`). Anything else (`DateTime`, `Uint8List`,
  `Iterable`, enums, custom classes) throws `ArgumentError` on write. Convert
  with `Timestamp.fromDateTime(dt)` / `timestamp.toDateTime()`,
  `Blob(bytes)` / `blob.bytes`, `iterable.toList()`, `myEnum.name`.
* A record's root value cannot be `null`; `put(db, null)` throws.
* Maps are cast to `Map<String, Object?>` and lists to `List<Object?>` on
  write. Typed maps such as `Map<String, int>` work; `Map<int, ...>` does not.
* Values returned by `get`, `find`, snapshots and streams are read-only:
  writing to them throws `StateError('read only')`. Clone before mutating:
  `cloneMap(value)`, `cloneList(value)`, `cloneValue(value)` from
  `package:sembast/utils/value_utils.dart`.
* Keep records small (a few KB). Store big binaries in files and keep a
  reference in the record.

### Transactions

* Group more than one write in `db.transaction((txn) async { ... })`. It is
  atomic (an exception rolls back every change and is rethrown) and much
  faster than separate writes: each standalone write is its own transaction.
* Inside the callback use only `txn`. Calling any method with `db` inside
  a transaction deadlocks (the call waits for the transaction that waits for
  it). Set `debugSembastWarnDatabaseCallInTransaction = true` during
  development to get a printed diagnosis after 10 s.
* The callback may return a value: `var key = await db.transaction((txn)
  => store.add(txn, value));`.
* Write helpers that take a `DatabaseClient client` parameter so they work
  with both `db` and `txn`.
* Make transaction bodies idempotent and side-effect free: on `sembast_web`
  and `sembast_sqflite` a transaction is re-run when another tab or process
  wrote concurrently.
* Reads inside a transaction see the transaction's pending changes; other
  readers see them after commit. Reads never need a transaction.
* Batch size: around 100-1000 writes per transaction; split larger imports.
* Do not open a nested `db.transaction` from inside a transaction (also a
  deadlock). The only exception is `onVersionChanged` during
  `openDatabase`, where `db` calls join the open transaction.

### Change triggers (in-transaction listeners)

* `store.addOnChangesListener(db, (txn, changes) async { ... })` runs inside
  the transaction that modified the store, before it commits. Use it for
  cascading deletes or derived data; use the `txn` argument for writes.
* Each `RecordChange` has `oldSnapshot`/`newSnapshot` (null for add/delete),
  `oldValue`/`newValue`, `ref`, and `isAdd`, `isUpdate`, `isDelete`.
* Writing to the same store from the listener triggers it again; guard
  against infinite loops. Remove with `store.removeOnChangesListener(db,
  sameCallback)`.
* `db.addAllStoresOnChangesListener(onChanges, excludedStoreNames: [...],
  storePredicate: (name) => ...)` is the untyped variant for every store.
* Register triggers right after opening, before the app uses the database.
  For reactive UI updates after commit use `onSnapshot`/`onSnapshots`
  streams instead (see the `sembast-query` skill).

## Examples

### Typed store with add, put, update, delete

```dart
import 'package:sembast/sembast.dart';

final animals = intMapStoreFactory.store('animals');

Future<void> crud(Database db) async {
  // Insert, generated int key.
  var key = await animals.add(db, {'name': 'cat', 'age': 4});

  // Upsert with an explicit key.
  await animals.record(100).put(db, {'name': 'dog'});

  // Merge fields into an existing record.
  await animals.record(key).update(db, {'age': 5, 'color': 'black'});

  // Read the value.
  var cat = await animals.record(key).get(db);
  print(cat); // {name: cat, age: 5, color: black}

  // Delete.
  await animals.record(100).delete(db);
  print(await animals.record(100).exists(db)); // false
}
```

### Key/value settings in the main store

```dart
import 'package:sembast/sembast.dart';

final settings = StoreRef<String, String>.main();
final themeRecord = settings.record('theme');

Future<String> getTheme(Database db) async =>
    await themeRecord.get(db) ?? 'light';

Future<void> setTheme(Database db, String theme) =>
    themeRecord.put(db, theme);
```

### Nested fields, dotted paths and FieldValue.delete

```dart
import 'package:sembast/sembast.dart';

final store = intMapStoreFactory.store('people');

Future<void> paths(Database db) async {
  var key = await store.add(db, {
    'name': 'Felix',
    'age': 4,
    'address': {'city': 'Ledignan'},
    'with.dots': 'kept as is by add',
  });
  var record = store.record(key);

  await record.update(db, {
    'address.city': 'San Francisco', // nested path
    'age': FieldValue.delete, // remove a field
    FieldKey.escape('with.dots'): 'literal key', // key containing a dot
  });
  print(await record.get(db));
  // {name: Felix, address: {city: San Francisco}, with.dots: literal key}
}
```

### Transaction with a returned value and a batch delete

```dart
import 'package:sembast/sembast.dart';

final shop = intMapStoreFactory.store('shop');

Future<List<int>> replaceAll(
  Database db,
  List<Map<String, Object?>> products,
) {
  return db.transaction((txn) async {
    // Only txn is used inside the transaction, never db.
    await shop.delete(txn);
    return shop.addAll(txn, products);
  });
}

Future<void> deleteSome(Database db, List<int> keys) =>
    db.transaction((txn) => shop.records(keys).delete(txn));
```

### Add or update by a unique field, race free

```dart
import 'package:sembast/sembast.dart';

final products = intMapStoreFactory.store('product');

/// Insert or update the product whose 'code' matches.
Future<void> addOrUpdateProduct(Database db, Map<String, Object?> map) {
  return db.transaction((txn) async {
    var existing = await products
        .query(finder: Finder(filter: Filter.equals('code', map['code'])))
        .getSnapshot(txn);
    if (existing == null) {
      await products.add(txn, map);
    } else {
      await existing.ref.update(txn, map);
    }
  });
}
```

### Helpers accepting a DatabaseClient

```dart
import 'package:sembast/sembast.dart';

final counters = StoreRef<String, int>('counters');

/// Works with a Database or a Transaction.
Future<int> increment(DatabaseClient client, String name) async {
  var record = counters.record(name);
  var value = (await record.get(client) ?? 0) + 1;
  await record.put(client, value);
  return value;
}

Future<void> incrementTwo(Database db) => db.transaction((txn) async {
      await increment(txn, 'a');
      await increment(txn, 'b');
    });
```

### Timestamp and Blob values

```dart
import 'dart:typed_data';

import 'package:sembast/blob.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/timestamp.dart';

final files = stringMapStoreFactory.store('files');

Future<void> saveFile(Database db, String id, Uint8List bytes) async {
  await files.record(id).put(db, {
    'createdAt': Timestamp.now(), // never a DateTime
    'thumbnail': Blob(bytes), // never a raw Uint8List
  });
  var value = await files.record(id).get(db);
  var createdAt = (value!['createdAt'] as Timestamp).toDateTime();
  var thumbnail = (value['thumbnail'] as Blob).bytes;
  print('$createdAt ${thumbnail.length} bytes');
}
```

### Clone a read value before modifying it

```dart
import 'package:sembast/sembast.dart';
import 'package:sembast/utils/value_utils.dart';

final store = intMapStoreFactory.store('notes');

Future<void> rename(Database db, int key) async {
  var value = await store.record(key).get(db);
  if (value == null) return;
  // value is read-only; value['title'] = 'x' would throw StateError.
  var map = cloneMap(value);
  map['title'] = 'Renamed';
  await store.record(key).put(db, map);
}
```

### Cascade delete with a store trigger

```dart
import 'package:sembast/sembast.dart';

final studentStore = intMapStoreFactory.store('student');
final enrollStore = intMapStoreFactory.store('enroll');

void setupTriggers(Database db) {
  studentStore.addOnChangesListener(db, (txn, changes) async {
    for (var change in changes) {
      if (change.isDelete) {
        // Same transaction: use txn.
        await enrollStore.delete(
          txn,
          finder: Finder(filter: Filter.equals('student', change.ref.key)),
        );
      }
    }
  });
}
```

## Common mistakes

* Using `db` instead of `txn` inside `db.transaction`: deadlock.
* Expecting `record.update` to create the record. It returns `null` and
  writes nothing; use `put` for upsert.
* Storing `DateTime`, `Uint8List`, an enum or a model object directly.
  Convert to `Timestamp`, `Blob`, `String` or `Map<String, Object?>` first.
* Mutating a map returned by `get`/`find` (`StateError('read only')`).
  `cloneMap` it.
* Passing dotted keys to `add`/`put` expecting nesting. Only `update` and
  `put(merge: true)` interpret `a.b` as a path.
* Looping `await store.add(db, ...)` over a big list without a transaction
  (`addAll` or one `db.transaction`).
* Declaring `StoreRef<Object, ...>` or a `double`/`bool` key type. Keys are
  `int` or `String`.

## More

See [references/api.md](references/api.md) for the full list of methods on
`StoreRef`, `RecordRef`, `RecordsRef`, `Database` and `DatabaseClient`,
including the synchronous variants.
