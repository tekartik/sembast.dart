---
name: sembast-query
description: >-
  Use when querying or listening to package:sembast data: Finder, Filter
  (equals, greaterThan, inList, matches, arrayContains, and/or/not, custom),
  SortOrder, Boundary paging, limit/offset, nested and list field paths
  (a.b, tag.0, items.@), Field.key, store.find/findFirst/findKeys/count,
  store.query() and QueryRef.getSnapshots/getSnapshot/count/delete, reactive
  streams record.onSnapshot, query.onSnapshots, onCount, and the synchronous
  getSync/findSync variants. Writes and transactions are in sembast-crud.
---

# sembast: queries, filters, sorting and listeners

Sembast keeps the whole database in memory, so queries are in-memory
filtering and sorting of a store. A `Finder` describes the query; run it once
with `store.find` / `store.findFirst` / `store.query(finder: f)`, or subscribe
to results with `onSnapshot(s)` streams that re-emit after each commit.

```dart
import 'package:sembast/sembast.dart';

final animals = intMapStoreFactory.store('animals');

Future<void> demo(Database db) async {
  var finder = Finder(
    filter: Filter.greaterThan('age', 2) & Filter.equals('kind', 'cat'),
    sortOrders: [SortOrder('name')],
    limit: 20,
  );
  var snapshots = await animals.find(db, finder: finder);
  for (var snapshot in snapshots) {
    print('${snapshot.key}: ${snapshot['name']}');
  }
}
```

## Guidelines

### Reading by key

* Fastest path: `store.record(key).get(client)` (value or null),
  `getSnapshot(client)`, `exists(client)`; several keys with
  `store.records(keys).get(client)` (a list with `null` for missing keys).
* A `RecordSnapshot` has `ref`, `key`, `value` and `operator [](field)` which
  resolves dotted paths (`snapshot['address.city']`), `Field.key` and
  `Field.value`. On an `Iterable<RecordSnapshot>` use `.keys`, `.values` and
  `.keysAndValues`.
* Snapshot values are read-only; clone with `cloneMap` from
  `package:sembast/utils/value_utils.dart` before editing.

### Finder

* `Finder({filter, sortOrders, limit, offset, start, end})`. Everything is
  optional; an empty `Finder()` matches every record. Order of application:
  filter, sort, boundaries, offset, limit.
* `store.find(client, finder: f)` returns `List<RecordSnapshot>`;
  `findFirst` the first or null; `findKeys` / `findKey` only keys;
  `store.count(client, filter: filter)` takes a `Filter`, not a `Finder`.
* `store.query(finder: f)` returns a reusable `QueryRef` with
  `getSnapshots`, `getSnapshot`, `getKeys`, `getKey`, `count`, `delete` (all
  taking a `DatabaseClient`) and the streams below (taking a `Database`).
* `store.stream(client, filter: filter)` iterates records unsorted without
  building a list; use it for one pass over a large store.

### Filters

* Field comparison: `Filter.equals(field, value)`, `notEquals`, `isNull`,
  `notNull`, `lessThan`, `lessThanOrEquals`, `greaterThan`,
  `greaterThanOrEquals`, `inList(field, list)`.
* Text: `Filter.matches(field, pattern)` compiles a `RegExp`;
  `Filter.matchesRegExp(field, RegExp(pattern, caseSensitive: false))` for
  options. The field must be a `String` to match.
* Lists: `Filter.arrayContains(field, value)`, `arrayContainsAny(field,
  values)`, `arrayContainsAll(field, values)`. `Filter.equals(field, value,
  anyInList: true)` and `matches(..., anyInList: true)` match when any list
  item matches.
* Combine with `a & b`, `a | b`, or `Filter.and([...])`, `Filter.or([...])`,
  `Filter.not(f)` for more than two.
* `Filter.byKey(key)` filters on the record key (`Field.key`); prefer
  `store.record(key)` when you have the key.
* `Filter.custom((snapshot) => bool)` runs Dart code per record. Read only,
  never modify the snapshot.
* Comparisons use sembast value ordering (`valuesCompare`): numbers,
  strings, `Timestamp` and `Blob` compare naturally; a missing or `null`
  field never satisfies a range filter. Compare a `Timestamp` field with a
  `Timestamp` value, never with a `DateTime`.

### Field paths

* `'a.b.c'` reaches nested maps, `'tags.0'` a list index, `'items.@.tag'`
  any item of a list (`Filter.equals('tags.@', 'x')` equals
  `Filter.equals('tags', 'x', anyInList: true)`). Escape a literal dot with
  `FieldKey.escape('my.key')`.
* `Field.key` (`'_key'`) sorts or filters by key. `Field.value` (`'_value'`)
  is the whole value, for stores whose values are not maps
  (`Filter.greaterThan(Field.value, 'hi')` on a `StoreRef<int, String>`).

### Sorting and paging

* `SortOrder(field, [ascending = true, nullLast = false])`. Several
  `sortOrders` give secondary ordering. `SortOrder.custom(field, compare)`
  applies your own comparator to that field's values (`SortOrder<T>` types
  the compared values).
* Without `sortOrders` results are in key order (insertion order for
  auto-increment int keys). `SortOrder(Field.key, false)` gives newest first.
* `limit` and `offset` page after sorting.
* Cursor paging: `Boundary(values: [...])` (one value per sort order) or
  `Boundary(record: lastSnapshot)` as `start`/`end`, exclusive unless
  `include: true`. Boundaries require `sortOrders`.

### Listening for changes

* `record.onSnapshot(db)` emits the current snapshot (or null) then again on
  every change; `records.onSnapshots(db)` for several keys.
* `store.query(finder: f).onSnapshots(db)` emits the full matching list
  after each commit that affects it; `onSnapshot(db)` the first match or
  null; `onKeys`/`onKey` the keys; `onCount(db)` the count.
* These streams are single-subscription and take a `Database` (never a
  `Transaction`). Always keep the `StreamSubscription` and `cancel()` it
  (in `dispose`) or memory leaks. Closing the database ends them.
* In Flutter feed them to `StreamBuilder`. Keep the `QueryRef` in a field
  or a `final` so the stream is created once, not on each `build`.
* For reacting inside the writing transaction (triggers) use
  `store.addOnChangesListener` (see `sembast-crud`).

### Synchronous API

* Reads have `Sync` variants that return directly: `record.getSync(client)`,
  `getSnapshotSync`, `existsSync`, `records.getSync`, `store.findSync`,
  `findFirstSync`, `findKeysSync`, `findKeySync`, `countSync`,
  `query.getSnapshotsSync`, `getSnapshotSync`, `getKeysSync`, `countSync`,
  and `onSnapshotSync`/`onSnapshotsSync`/`onCountSync` streams whose first
  event is delivered synchronously.
* Use them for key lookups and small stores (initial UI state). Large sorted
  or filtered queries block the isolate; prefer the async API, which yields
  periodically (the cooperator) to keep the UI responsive.

### No aggregates or joins

* There is no sum/avg/group-by: fetch snapshots and reduce in Dart. There are
  no indexes: every query scans the store, which is fine below ~100K records.
* Store denormalized data or run a second query for related records.

## Examples

### Filter, sort and page

```dart
import 'package:sembast/sembast.dart';

final products = intMapStoreFactory.store('product');

Future<List<RecordSnapshot<int, Map<String, Object?>>>> cheapFirst(
  Database db, {
  int page = 0,
  int pageSize = 20,
}) {
  var finder = Finder(
    filter: Filter.lessThan('price', 100) & Filter.notNull('name'),
    sortOrders: [SortOrder('price'), SortOrder('name')],
    limit: pageSize,
    offset: page * pageSize,
  );
  return products.find(db, finder: finder);
}
```

### Text search across fields within a date range

```dart
import 'package:sembast/sembast.dart';
import 'package:sembast/timestamp.dart';

final invoices = intMapStoreFactory.store('invoice');

Future<List<Map<String, Object?>>> search(
  Database db,
  String text,
  int year,
) async {
  var regExp = RegExp(RegExp.escape(text), caseSensitive: false);
  var filter = Filter.and([
    Filter.or([
      Filter.matchesRegExp('clientName', regExp),
      Filter.matchesRegExp('companyName', regExp),
    ]),
    Filter.greaterThanOrEquals('date', Timestamp.fromDateTime(DateTime(year))),
    Filter.lessThan('date', Timestamp.fromDateTime(DateTime(year + 1))),
  ]);
  var snapshots = await invoices.find(
    db,
    finder: Finder(filter: filter, sortOrders: [SortOrder('date', false)]),
  );
  return snapshots.values.toList();
}
```

### Nested and list fields

```dart
import 'package:sembast/sembast.dart';

final items = intMapStoreFactory.store('items');

Future<void> nested(Database db) async {
  await items.addAll(db, [
    {
      'name': 'Lamp',
      'product': {'code': '1F8'},
      'tags': ['light', 'wood'],
      'attributes': [
        {'tag': 'furniture'},
        {'tag': 'plastic'},
      ],
    },
  ]);
  var byCode = await items.findFirst(
    db,
    finder: Finder(filter: Filter.equals('product.code', '1F8')),
  );
  print(byCode?['product.code']); // 1F8

  var wood = await items.find(
    db,
    finder: Finder(filter: Filter.arrayContains('tags', 'wood')),
  );
  var furniture = await items.find(
    db,
    finder: Finder(filter: Filter.equals('attributes.@.tag', 'furniture')),
  );
  var sortedByFirstTag = await items.find(
    db,
    finder: Finder(sortOrders: [SortOrder('tags.0')]),
  );
  print('${wood.length} ${furniture.length} ${sortedByFirstTag.length}');
}
```

### Last inserted record and key-based queries

```dart
import 'package:sembast/sembast.dart';

final logs = intMapStoreFactory.store('log');

Future<RecordSnapshot<int, Map<String, Object?>>?> lastLog(Database db) =>
    logs.findFirst(
      db,
      finder: Finder(sortOrders: [SortOrder(Field.key, false)]),
    );

Future<int> countErrors(Database db) =>
    logs.query(finder: Finder(filter: Filter.equals('level', 'error')))
        .count(db);

Future<int> purgeOldLogs(Database db, int maxKey) => logs
    .query(finder: Finder(filter: Filter.lessThan(Field.key, maxKey)))
    .delete(db);
```

### Cursor paging with Boundary

```dart
import 'package:sembast/sembast.dart';

final shop = intMapStoreFactory.store('shop');

/// Returns the page after [last] (or the first page when null).
Future<List<RecordSnapshot<int, Map<String, Object?>>>> nextPage(
  Database db, {
  RecordSnapshot<int, Map<String, Object?>>? last,
  int pageSize = 10,
}) {
  var finder = Finder(
    sortOrders: [SortOrder('price'), SortOrder('name')],
    start: last == null ? null : Boundary(record: last),
    limit: pageSize,
  );
  return shop.find(db, finder: finder);
}

// Equivalent explicit boundary: Boundary(values: [10, 'Chair']) skips
// everything up to price 10 / name 'Chair'.
```

### Listen to a query and a single record

```dart
import 'dart:async';

import 'package:sembast/sembast.dart';

final todos = intMapStoreFactory.store('todo');

class TodoWatcher {
  TodoWatcher(this.db);
  final Database db;
  late final StreamSubscription<List<RecordSnapshot<int, Map<String, Object?>>>>
      _listSubscription;
  late final StreamSubscription<RecordSnapshot<int, Map<String, Object?>>?>
      _recordSubscription;

  void start(int watchedKey) {
    var query = todos.query(
      finder: Finder(
        filter: Filter.equals('done', false),
        sortOrders: [SortOrder('createdAt')],
      ),
    );
    // Emits the current list, then again after every relevant commit.
    _listSubscription = query.onSnapshots(db).listen((snapshots) {
      print('${snapshots.length} pending todos');
    });
    // null when the record does not exist or gets deleted.
    _recordSubscription =
        todos.record(watchedKey).onSnapshot(db).listen((snapshot) {
      print('todo $watchedKey: ${snapshot?.value}');
    });
  }

  Future<void> dispose() async {
    await _listSubscription.cancel();
    await _recordSubscription.cancel();
  }
}
```

### Flutter StreamBuilder over a query

```dart
// Flutter widget sketch (needs package:flutter).
// final query = store.query(finder: Finder(sortOrders: [SortOrder('name')]));
//
// StreamBuilder<List<RecordSnapshot<int, Map<String, Object?>>>>(
//   stream: query.onSnapshots(db), // created once, in a field or initState
//   builder: (context, snapshot) {
//     var items = snapshot.data ?? [];
//     return ListView(
//       children: [for (var item in items) Text('${item['name']}')],
//     );
//   },
// )
```

### Custom filter and custom sort

```dart
import 'package:sembast/sembast.dart';

final people = intMapStoreFactory.store('people');

Future<List<RecordSnapshot<int, Map<String, Object?>>>> adultsByLastName(
  Database db,
) {
  var finder = Finder(
    filter: Filter.custom((snapshot) => (snapshot['age'] as int? ?? 0) >= 18),
    sortOrders: [
      SortOrder<String>.custom(
        'name',
        (a, b) => a.split(' ').last.compareTo(b.split(' ').last),
      ),
    ],
  );
  return people.find(db, finder: finder);
}
```

### Synchronous read for initial state

```dart
import 'package:sembast/sembast.dart';

final settings = StoreRef<String, Object>.main();

/// Cheap key lookup, safe to call synchronously (for example in a getter).
bool darkMode(Database db) =>
    settings.record('darkMode').getSync(db) as bool? ?? false;
```

## Common mistakes

* Passing a `Finder` to `store.count(db, filter: ...)`; it takes a `Filter`.
  Use `store.query(finder: f).count(db)` for a full finder.
* Listening with a `Transaction` (`onSnapshots(txn)` does not compile); the
  streams take a `Database`.
* Forgetting to cancel `onSnapshot`/`onSnapshots` subscriptions, or creating
  a new stream in every `build`.
* Comparing a `Timestamp` field with a `DateTime` value: no record matches.
* Using `Boundary` without `sortOrders`.
* Expecting `Filter.matches` to work on non-string fields (it does not
  match) or forgetting `RegExp.escape` on user input.
* Running big sorted queries with the `Sync` API on the UI isolate.

## More

See [references/filters.md](references/filters.md) for the complete `Filter`,
`SortOrder`, `Boundary` and `QueryRef` listings and the value ordering rules.
