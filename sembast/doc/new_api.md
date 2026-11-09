# Migrating from the 1.x API

As of 1.15.0, there is a new API available to manipulate data in the database. 
Previous API had too many `dynamic` types. Switching to the new API makes it less
error-prone. The old API was available up to v2.3.0 to allow a smooth migration, it has been removed since then.

The old API is still found in old tutorials and in code written by AI assistants. If your code calls
`db.put(value, key)`, `db.getStore('name')` or uses the `Store` and `Record` classes, it is the old API and it does
not compile anymore.

## Old API (1.x) to current API

In the current API, a `StoreRef` or a `RecordRef` is only a pointer: it holds no data and does not depend on the
database. Declare them once (globally) and pass the `Database` (or the `Transaction` in a transaction) as the first
argument of every call.

| Old 1.x code | Current code |
|---|---|
| `db.put(value, key)` | `StoreRef.main().record(key).put(db, value)` |
| `db.put(value)` (generated key) | `intMapStoreFactory.store().add(db, value)` |
| `db.get(key)` | `StoreRef.main().record(key).get(db)` |
| `db.mainStore` | `StoreRef.main()`, `intMapStoreFactory.store()` |
| `Store store = db.getStore('pets')`, `db.findStore('pets')` | `var store = intMapStoreFactory.store('pets')` (int keys, map values), `stringMapStoreFactory.store('pets')` (String keys) or `StoreRef<K, V>('pets')` |
| `db.stores`, `db.storeNames` | `getNonEmptyStoreNames(db)` (`package:sembast/utils/database_utils.dart`) |
| `db.deleteStore('pets')` | `store.drop(db)` |
| `store.put(value)` (generated key) | `store.add(db, value)` |
| `store.put(value, key)` | `store.record(key).put(db, value)` |
| `store.get(key)` | `store.record(key).get(db)` |
| `store.update(value, key)` | `store.record(key).update(db, value)` |
| `store.delete(key)` | `store.record(key).delete(db)` |
| `store.deleteAll(keys)` | `store.records(keys).delete(db)` |
| `store.clear()` | `store.delete(db)` |
| `store.containsKey(key)` | `store.record(key).exists(db)` |
| `store.getRecord(key)`, `db.getRecord(key)` | `store.record(key).getSnapshot(db)` |
| `store.getRecords(keys)` | `store.records(keys).getSnapshots(db)` |
| `store.records` (a `Stream<Record>`) | `store.stream(db)` |
| `store.count(filter)` | `store.count(db, filter: filter)` |
| `store.findRecords(finder)`, `db.findRecords(finder)` | `store.find(db, finder: finder)` |
| `store.findRecord(finder)` | `store.findFirst(db, finder: finder)` |
| `store.findKeys(finder)`, `store.findKey(finder)` | `store.findKeys(db, finder: finder)`, `store.findKey(db, finder: finder)` |
| `db.putRecord(Record(store, value, key))` | `store.record(key).put(db, value)` |
| `db.putRecords(records)` | `store.records(keys).put(db, values)` |
| `db.deleteRecord(record)` | `snapshot.ref.delete(db)` |
| `record.key`, `record.value` (a `Record`) | `snapshot.key`, `snapshot.value` (a `RecordSnapshot`) |
| `record['name'] = 'x'` then `db.putRecord(record)` | `var map = cloneMap(snapshot.value)`, `map['name'] = 'x'`, `snapshot.ref.put(db, map)` |
| `updateRecords(store, values, where: finder)` | `store.update(db, values, finder: finder)` |
| `db.transaction((txn) async { await txn.put(value, key); })` | `db.transaction((txn) async { await store.record(key).put(txn, value); })` |
| `txn.getStore('pets')` | the same `StoreRef`, used with `txn` |
| `Filter.equal`, `Filter.notEqual` | `Filter.equals`, `Filter.notEquals` |
| `FilterOperation`, `FilterPredicate`, `CompositeFilter` | the `Filter` constructors, `Filter.and([...])`, `Filter.or([...])`, `&`, `\|` |
| `ioDatabaseFactory`, `memoryDatabaseFactory`, `memoryFsDatabaseFactory` | `databaseFactoryIo`, `databaseFactoryMemory`, `databaseFactoryMemoryFs` |
| `databaseModeCreate`, `databaseModeExisting`, `databaseModeEmpty`, `databaseModeNeverFails` | `DatabaseMode.create`, `DatabaseMode.existing`, `DatabaseMode.empty`, `DatabaseMode.neverFails` |

`Finder` (`filter`, `sortOrders`, `limit`, `offset`, `start`, `end`), `SortOrder`, `Boundary`, `Field.key` and the
other `Filter` constructors (`Filter.equals`, `Filter.greaterThan`, `Filter.matches`...) did not change.

`cloneMap` comes from `package:sembast/utils/value_utils.dart`.

## The new API

The new `Store` API allows you to enforce the type of keys and values:

```dart
// Use the main store for storing key values as String
var store = StoreRef<String, String>.main();

// Writing the data
await store.record('username').put(db, 'my_username');
await store.record('url').put(db, 'my_url');

// Reading the data
var url = await store.record('url').get(db);
var username = await store.record('username').get(db);
```

It also makes access in `Transaction` and `Database` more similar:

```dart
await db.transaction((txn) async {
  url = await store.record('url').get(txn);
  username = await store.record('username').get(txn);
});

```

## Examples

### Listen to changes

You can listen to specific record changes

```dart
// Track record changes
var subscription = record.onSnapshot(db).listen((snapshot) {
  // if snapshot is null, the record is not present or has been
  // deleted

  // ...
});

// ...

// cancel subscription. Important! not doing this might lead to
// memory leaks
unawaited(subscription?.cancel());
```

You can listen to changes for a given query in a store

```dart
// Track query changes
var query = store.query(finder: finder);
var subscription = query.onSnapshots(db).listen((snapshots) {
  // snapshots always contains the list of records matching the query

  // ...
});

// ...

// cancel subscription. Important! not doing this might lead to
// memory leaks
unawaited(subscription?.cancel());
```

More information [here](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/change_listener.md).

## New API migration examples

Some examples to migrate your code:

### Put get data

#### Before

```dart
// Cast necessary to manipulate the key
var key = await db.put({'offline': true}) as int;
Record record = await db.getRecord(key);
// Cast necessary to manipulate the data
var value = record.value as Map<String, Object?>;

```

#### After

Put/Get using an auto-generated key:

```dart
// Lint warnings will warn you if you try to use different types
var store = intMapStoreFactory.store();
// autogenerate a key
var key = await store.add(db, {'offline': true});
var value = await store.record(key).get(db);
```

Create a record with a given key:
```dart
// specify a key
key = 1234;
await store.record(key).put(db, {'offline': true});
```

### Find


#### Before

```dart
Record record = await db.findRecord(finder);
// Cast necessary to manipulate the data
var value = record.value as Map<String, Object?>;

```

#### After

```dart
// No cast needed
var value = await store.findFirst(db, finder: finder);

```
