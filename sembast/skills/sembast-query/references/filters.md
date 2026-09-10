# sembast query API reference

All from `package:sembast/sembast.dart`.

## Finder

`Finder({Filter? filter, List<SortOrder>? sortOrders, int? limit, int?
offset, Boundary? start, Boundary? end})`. Setters exist for every part
(`finder.filter = ...`, `finder.sortOrder = SortOrder(...)` for a single
order). Boundaries (`start`/`end`) apply after filtering and sorting and
require `sortOrders` when `values` are given.

## Filter factories

| Factory | Matches when |
|---|---|
| `Filter.equals(field, value, {anyInList})` | field == value (or any list item when `anyInList`) |
| `Filter.notEquals(field, value)` | field != value |
| `Filter.isNull(field)` | field is null or missing |
| `Filter.notNull(field)` | field is present and not null |
| `Filter.lessThan(field, value)` | field < value |
| `Filter.lessThanOrEquals(field, value)` | field <= value |
| `Filter.greaterThan(field, value)` | field > value |
| `Filter.greaterThanOrEquals(field, value)` | field >= value |
| `Filter.inList(field, List<Object> list)` | field is one of list |
| `Filter.matches(field, String pattern, {anyInList})` | String field matches `RegExp(pattern)` |
| `Filter.matchesRegExp(field, RegExp regExp, {anyInList})` | String field matches regExp |
| `Filter.arrayContains(field, Object value)` | list field contains value |
| `Filter.arrayContainsAny(field, List<Object> values)` | list field contains at least one |
| `Filter.arrayContainsAll(field, List<Object> values)` | list field contains all |
| `Filter.and(List<Filter>)` / `a & b` | all match |
| `Filter.or(List<Filter>)` / `a \| b` | any matches |
| `Filter.not(Filter)` | does not match |
| `Filter.byKey(key)` | record key == key (`Field.key`) |
| `Filter.custom(bool Function(RecordSnapshot) matches)` | callback returns true |

`Filter` must not be subclassed. The `&` and `|` operators come from the
`SembastFilterCombination` extension.

## Field names

* Dotted path into maps: `'a.b.c'`.
* List index: `'list.0'`; any list item: `'list.@'` (also nested:
  `'items.@.tag'`).
* Literal dot in a key: `FieldKey.escape('a.b')` (wraps in backticks).
* `Field.key` = `'_key'`, `Field.value` = `'_value'` (the whole value, for
  non-map stores).

## Value ordering

Sorting and range filters use `valuesCompare` from
`package:sembast/utils/value_utils.dart`: `num` by value, `String`
lexicographically (code units), `bool`, `Timestamp`, `Blob` through
`compareTo`. A `null` or missing field never matches `lessThan`/`greaterThan`
style filters. In `SortOrder`, nulls come first when ascending unless
`nullLast` is true.

## SortOrder

* `SortOrder(String field, [bool ascending = true, bool nullLast = false])`
* `SortOrder<T>.custom(String field, int Function(T a, T b) compare, [bool
  ascending = true, bool nullLast = false])`

## Boundary

`Boundary({RecordSnapshot? record, bool? include, List<Object?>? values})`.
`values` (one per sort order) takes precedence over `record`. `include`
defaults to false (exclusive).

## StoreRef read methods

`find(client, {finder})`, `findFirst(client, {finder})`, `findKey(client,
{finder})`, `findKeys(client, {finder})`, `count(client, {filter})`,
`stream(client, {filter})`, `onCount(db, {filter})`, and `findSync`,
`findFirstSync`, `findKeySync`, `findKeysSync`, `countSync`.

## QueryRef (`store.query({finder})`)

| Method | Returns |
|---|---|
| `getSnapshots(client)` | `Future<List<RecordSnapshot<K, V>>>` |
| `getSnapshot(client)` | `Future<RecordSnapshot<K, V>?>` (first) |
| `getKeys(client)` | `Future<List<K>>` |
| `getKey(client)` | `Future<K?>` |
| `count(client)` | `Future<int>` |
| `delete(client)` | `Future<int>` deleted count |
| `onSnapshots(db)` | `Stream<List<RecordSnapshot<K, V>>>` |
| `onSnapshot(db)` | `Stream<RecordSnapshot<K, V>?>` |
| `onKeys(db)` | `Stream<List<K>>` |
| `onKey(db)` | `Stream<K?>` |
| `onCount(db)` | `Stream<int>` |
| `finder` | the `Finder?` used (`SembastQueryRefCommonExtension`) |

Synchronous (`SembastQueryRefSyncExtension`): `getSnapshotsSync`,
`getSnapshotSync`, `getKeysSync`, `getKeySync`, `countSync`,
`onSnapshotsSync`, `onSnapshotSync`, `onKeysSync`, `onKeySync`,
`onCountSync` (first event synchronous).

All `on*` streams are single-subscription; cancel them. They emit an initial
value on listen, then after every transaction commit that changed a matching
record (list streams re-emit the whole list).

## RecordRef / RecordsRef listeners

`record.onSnapshot(db)`, `record.onSnapshotSync(db)`,
`records.onSnapshots(db)`, `records.onSnapshotsSync(db)`.

## Cooperator

Long filter/sort passes pause 100 microseconds every 4 ms so the UI isolate
stays responsive. `disableSembastCooperator()` /
`enableSembastCooperator({delayMicroseconds, pauseMicroseconds})` from
`package:sembast/sembast.dart` control it (disable in pure CLI code or in
`flutter_test`, where the internal `Future.delayed` can hang).
