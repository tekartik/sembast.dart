---
name: sembast-web-setup
description: >-
  Use when a sembast database must work in a browser or Flutter web app:
  package:sembast_web, databaseFactoryWeb, databaseFactoryWebWorker,
  IndexedDB database names, choosing the factory per platform with a
  conditional import next to sembast_io / sembast_sqflite, cross-tab
  synchronization, re-run (idempotent) transactions, checkForChanges, web
  limitations (int/String keys, JavaScript number range, size, codecs) and
  testing web code on the VM with the memory jdb factory.
---

# sembast_web: sembast on IndexedDB

`package:sembast_web` provides `databaseFactoryWeb`, a `DatabaseFactory`
storing each sembast database in one IndexedDB database. It works with
`dart:js_interop` (JavaScript and WASM builds). The data API is the regular
`package:sembast` API; only the factory changes.

```dart
import 'package:sembast_web/sembast_web.dart'; // re-exports sembast.dart

final store = intMapStoreFactory.store('product');

Future<void> demo() async {
  // The path is an IndexedDB database name, not a file path.
  var db = await databaseFactoryWeb.openDatabase('my_app.db');
  var key = await store.add(db, {'name': 'Table', 'price': 15});
  print(await store.record(key).get(db));
  await db.close();
}
```

## Guidelines

### Dependencies and imports

* Add `sembast_web` next to `sembast` in `pubspec.yaml`. Import
  `package:sembast_web/sembast_web.dart`; it re-exports
  `package:sembast/sembast.dart` so `StoreRef`, `Finder`, etc. are available.
* Exported factories: `databaseFactoryWeb` (page/main thread) and
  `databaseFactoryWebWorker` (inside a web worker). `sembast_web_html.dart`
  only holds a deprecated `databaseFactoryWeb` alias; do not use it.
* The import compiles on the VM and in Flutter mobile/desktop builds, but
  the getters throw `UnimplementedError` there. Select the factory with a
  conditional import when the app also targets io (example below), or use
  `tekartik_app_flutter_sembast`'s `getDatabaseFactory()` which does it.

### Database name and location

* `openDatabase(name)` takes an IndexedDB name scoped to the origin
  (scheme + host + port). `localhost:8080` and `localhost:8081` are different
  origins: use a fixed `--web-port` while debugging or the data "disappears".
* Directory-like names (`'data/my.db'`) are allowed; they are just names.
  `factory.sandbox(path: 'prefix')` from sembast prefixes them. There is no
  file, no `path_provider`, no directory creation.
* `deleteDatabase(name)` and `databaseExists(name)` work. Close the database
  before deleting it.
* Storage is per browser profile and subject to the browser's IndexedDB
  quota and eviction; treat it as a cache unless persistence is granted.
  Keep it small (guideline: below ~30K records).

### Cross-tab behavior

* Every tab or worker that opens the same database keeps its own in-memory
  copy. Writes go to IndexedDB in a journal with a revision number; other
  tabs are notified through a `BroadcastChannel` and load only the new
  records, so `onSnapshot`/`onSnapshots` listeners fire in every tab.
* Transactions are cross-tab safe: if another tab committed since the
  transaction started, the local data is refreshed and the transaction
  callback runs again. Transaction bodies must therefore be idempotent and
  free of side effects (no UI updates, no network calls, no incrementing
  outside variables inside the callback). Compute results from the data read
  inside the callback.
* `await db.checkForChanges()` forces an immediate refresh from IndexedDB
  (normally not needed; notifications handle it).
* `db.compact()` purges the journal history.

### Data and API limitations

* Keys: `int` or `String` only, as in sembast. Auto-increment int keys and
  generated string keys work.
* Values: the sembast types (`String`, `num`, `bool`, `null`,
  `Map<String, Object?>`, `List<Object?>`, `Timestamp`, `Blob`). `DateTime`
  and `Uint8List` are still rejected: use `Timestamp` and `Blob`.
* When compiled to JavaScript (not WASM) an `int` is a JS number: values and
  keys above 2^53 lose precision. Store 64-bit ids as `String`.
* `Timestamp` round-trips at microsecond precision on the VM but the
  platform `DateTime` only has millisecond precision on JavaScript; do not
  rely on sub-millisecond values in web code.
* `codec:` is accepted (sync codecs and `AsyncContentCodecBase`) and the
  signature is checked, but the README states codecs are not supported on
  the web and browser-side encryption gives no real protection: keep secrets
  off the client or encrypt individual fields yourself.
* Everything else (queries, listeners, triggers, import/export,
  `onVersionChanged` migrations) behaves as in sembast.

### Testing

* Unit tests that must run on the VM: use `newDatabaseFactoryMemory()`
  from `package:sembast/sembast_memory.dart`, or `databaseFactoryMemoryJdb`
  from `package:sembast/utils/jdb.dart` to reproduce the journal semantics
  (re-run transactions) without a browser.
* Browser tests: `dart test -p chrome` with `databaseFactoryWeb`; delete the
  database at the start of each test.

## Examples

### Factory selection with a conditional import

`lib/db/db_factory.dart`:

```dart
import 'package:sembast/sembast.dart';

import 'db_factory_stub.dart'
    if (dart.library.js_interop) 'db_factory_web.dart'
    if (dart.library.io) 'db_factory_io.dart' as impl;

/// The database factory for the current platform.
DatabaseFactory get appDatabaseFactory => impl.appDatabaseFactory;

/// Resolves the database path or name for the current platform.
Future<String> appDatabasePath(String name) => impl.appDatabasePath(name);
```

`lib/db/db_factory_web.dart`:

```dart
import 'package:sembast_web/sembast_web.dart';

DatabaseFactory get appDatabaseFactory => databaseFactoryWeb;

// IndexedDB name: nothing to resolve.
Future<String> appDatabasePath(String name) async => name;
```

`lib/db/db_factory_io.dart` (Flutter, with `path_provider`):

```dart
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

DatabaseFactory get appDatabaseFactory => databaseFactoryIo;

Future<String> appDatabasePath(String name) async {
  var dir = await getApplicationDocumentsDirectory();
  await dir.create(recursive: true);
  return join(dir.path, name);
}
```

`lib/db/db_factory_stub.dart`:

```dart
import 'package:sembast/sembast.dart';

DatabaseFactory get appDatabaseFactory =>
    throw UnsupportedError('No sembast factory for this platform');

Future<String> appDatabasePath(String name) =>
    throw UnsupportedError('No sembast factory for this platform');
```

Usage, identical on every platform:

```dart
import 'package:sembast/sembast.dart';

import 'db/db_factory.dart';

Future<Database> openAppDatabase() async {
  var path = await appDatabasePath('my_app.db');
  return appDatabaseFactory.openDatabase(path, version: 1);
}
```

### Idempotent transaction (safe when re-run after a concurrent write)

```dart
import 'package:sembast_web/sembast_web.dart';

final counters = StoreRef<String, int>('counters');

/// Increments atomically even with several tabs; the body may run twice.
Future<int> nextSequence(Database db, String name) {
  return db.transaction((txn) async {
    var record = counters.record(name);
    var value = (await record.get(txn) ?? 0) + 1;
    await record.put(txn, value);
    return value; // Derived from data read inside the transaction only.
  });
}
```

### Listening across tabs

```dart
import 'dart:async';

import 'package:sembast_web/sembast_web.dart';

final notes = stringMapStoreFactory.store('note');

StreamSubscription<List<RecordSnapshot<String, Map<String, Object?>>>>
    watchNotes(Database db) {
  // Also fires when another tab adds, updates or deletes a note.
  return notes
      .query(finder: Finder(sortOrders: [SortOrder('updatedAt', false)]))
      .onSnapshots(db)
      .listen((snapshots) => print('${snapshots.length} notes'));
}
```

### VM test reproducing journal (re-run) semantics

```dart
import 'package:sembast/sembast.dart';
import 'package:sembast/utils/jdb.dart';
import 'package:test/test.dart';

void main() {
  test('idempotent transaction', () async {
    var factory = databaseFactoryMemoryJdb;
    await factory.deleteDatabase('test');
    var db = await factory.openDatabase('test');
    var record = StoreRef<String, int>.main().record('count');
    await db.transaction((txn) async {
      await record.put(txn, (await record.get(txn) ?? 0) + 1);
    });
    expect(await record.get(db), 1);
    await db.close();
  });
}
```

## Common mistakes

* Using `databaseFactoryIo` in a web build (`UnimplementedError`) or
  `databaseFactoryWeb` in a mobile build; use the conditional import.
* Treating the database name as a file path (`getApplicationDocumentsDirectory`
  does not exist on the web).
* Running non-idempotent code inside `db.transaction` (network calls,
  counters in closures): it can execute twice on the web.
* Debugging Flutter web on a random port and losing the IndexedDB data.
* Storing 64-bit integers or `DateTime` values; use `String` ids and
  `Timestamp`.
* Relying on browser storage as the only copy of important data.
