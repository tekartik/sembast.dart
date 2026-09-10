# sembast CRUD API reference

All from `package:sembast/sembast.dart` (version 3.8.x). `client` is a
`DatabaseClient`: a `Database` or a `Transaction`. `db` must be a `Database`.

## StoreRef<K, V>

Construction: `StoreRef<K, V>(name)`, `StoreRef<K, V>.main()`,
`intMapStoreFactory.store([name])`, `stringMapStoreFactory.store([name])`.
Properties: `name`, `record(key)`, `records(keys)`, `recordsFromRefs(refs)`,
`cast<RK, RV>()`.

| Method | Returns | Notes |
|---|---|---|
| `add(client, value)` | `Future<K>` | generated key |
| `addAll(client, values)` | `Future<List<K>>` | one transaction |
| `update(client, value, {finder})` | `Future<int>` | merge into matching records, count |
| `delete(client, {finder})` | `Future<int>` | all records when no finder |
| `drop(client)` | `Future<void>` | delete store content |
| `generateKey(client)` | `Future<K>` | |
| `generateIntKey(client)` | `Future<int>` | |
| `find(client, {finder})` | `Future<List<RecordSnapshot>>` | |
| `findFirst(client, {finder})` | `Future<RecordSnapshot?>` | |
| `findKey(client, {finder})` | `Future<K?>` | |
| `findKeys(client, {finder})` | `Future<List<K>>` | |
| `count(client, {filter})` | `Future<int>` | prefer `query(...).count` |
| `stream(client, {filter})` | `Stream<RecordSnapshot>` | unsorted, one pass |
| `query({finder})` | `QueryRef<K, V>` | see sembast-query |
| `onCount(db, {filter})` | `Stream<int>` | prefer `query(...).onCount` |
| `addOnChangesListener(db, listener)` | `void` | in-transaction trigger |
| `removeOnChangesListener(db, listener)` | `void` | same callback instance |

Synchronous reads (`SembastStoreRefSyncExtension`): `findSync`,
`findFirstSync`, `findKeySync`, `findKeysSync`, `countSync`.

## RecordRef<K, V>

Properties: `store`, `key`, `cast<RK, RV>()`, `snapshot(value)` (builds a
`RecordSnapshot` without touching the database).

| Method | Returns | Notes |
|---|---|---|
| `add(client, value)` | `Future<K?>` | null if it already exists |
| `put(client, value, {merge, ifNotExists})` | `Future<V>` | upsert |
| `update(client, value)` | `Future<V?>` | null if missing, dotted paths |
| `get(client)` | `Future<V?>` | |
| `getSnapshot(client)` | `Future<RecordSnapshot?>` | |
| `exists(client)` | `Future<bool>` | |
| `delete(client)` | `Future<K?>` | null if missing |
| `onSnapshot(db)` | `Stream<RecordSnapshot?>` | single-subscription, cancel it |

Synchronous (`SembastRecordRefSyncExtension`): `getSync`, `getSnapshotSync`,
`existsSync`, `onSnapshotSync` (first event delivered synchronously).

## RecordsRef<K, V>

Properties: `store`, `keys`, `length`, `refs`, `[index]`, `cast<RK, RV>()`.

| Method | Returns | Notes |
|---|---|---|
| `add(client, values)` | `Future<List<K?>>` | null where it existed |
| `put(client, values, {merge})` | `Future<List<V>>` | values match keys |
| `update(client, values)` | `Future<List<V?>>` | null where missing |
| `get(client)` | `Future<List<V?>>` | |
| `getSnapshots(client)` | `Future<List<RecordSnapshot?>>` | |
| `delete(client)` | `Future<List<K?>>` | |
| `onSnapshots(db)` | `Stream<List<RecordSnapshot?>>` | |

Synchronous: `getSync`, `getSnapshotsSync`, `onSnapshotsSync`.

## RecordSnapshot<K, V>

`ref`, `key`, `value`, `operator [](field)` (dotted path, `Field.key`,
`Field.value`), `cast<RK, RV>()`. On `Iterable<RecordSnapshot>`: `keys`,
`values`, `keysAndValues` (records `(K, V)`).

## Database

`version`, `path`, `transaction(action)`, `close()`, and the
`DatabaseExtension`: `compact()`, `checkForChanges()`, `reOpen()`,
`reload()`. `addAllStoresOnChangesListener(onChanges, {excludedStoreNames,
storePredicate})` / `removeAllStoresOnChangesListener(onChanges)`.

## DatabaseClient

`dropAll()` deletes every store. Any `DatabaseClient` can be passed to the
store/record methods above.

## RecordChange<K, V> (triggers)

`oldSnapshot`, `newSnapshot`, `oldValue`, `newValue`, `ref`, `isAdd`,
`isUpdate`, `isDelete`, `cast<RK, RV>()`. Listener type:
`TransactionRecordChangeListener<K, V> = FutureOr<void> Function(Transaction
transaction, List<RecordChange<K, V>> changes)`.

## Field helpers

* `Field.key` (`'_key'`) and `Field.value` (`'_value'`): special field names
  usable in filters, sort orders and `snapshot[...]`.
* `FieldValue.delete`: sentinel removing a field in `update`/merge.
* `FieldKey.escape(name)`: wraps a key in backticks so a dot is literal.

## Value utilities (`package:sembast/utils/value_utils.dart`)

`cloneMap(map)`, `cloneList(list)`, `cloneValue(value)`,
`valuesCompare(a, b)` (the ordering used by sort orders and range filters),
`jsonEncodableSort(value)`.

## Timestamp (`package:sembast/timestamp.dart`)

`Timestamp(seconds, nanoseconds)`, `Timestamp.now()`,
`Timestamp.fromDateTime(dt)`, `Timestamp.fromMillisecondsSinceEpoch(ms)`,
`Timestamp.fromMicrosecondsSinceEpoch(us)`, `Timestamp.parse(text)`,
`Timestamp.tryParse(text)`, `Timestamp.tryAnyAsTimestamp(any)`,
`Timestamp.zero`; instance: `seconds`, `nanoseconds`, `toDateTime({isUtc})`,
`toIso8601String()`, `compareTo`, `addDuration(d)`, `substractDuration(d)`,
`difference(other)`. Timestamps carry no time zone; `fromDateTime` gives the
same result for local and UTC input.

## Blob (`package:sembast/blob.dart`)

`Blob(Uint8List bytes)`, `Blob.fromList(List<int>)`, `Blob.fromBase64(text)`;
`bytes`, `length`, `[index]`, `toBase64()`, `compareTo`.
