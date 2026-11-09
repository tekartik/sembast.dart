---
name: sembast-web-setup
description: >-
  Use when a sembast database must work in a browser or Flutter web app:
  package:sembast_web, databaseFactoryWeb, databaseFactoryWebWorker,
  IndexedDB database names (no path_provider, no folder), one code base for
  web, mobile and desktop (kIsWeb or a conditional import choosing
  databaseFactoryWeb or sembast_io / sembast_sqflite), cross-tab
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
  the getters throw `UnimplementedError` there. `package:sembast/sembast_io.dart`
  also compiles on the web (its `databaseFactoryIo` throws there). So in
  Flutter, `kIsWeb` is enough to pick the factory; without Flutter, or to
  keep `path_provider` out of the web build, use a conditional import
  (examples below). The git package `tekartik_app_flutter_sembast` (not on
  pub.dev) has a `getDatabaseFactory()` doing it with sembast_sqflite.

### Database name and location

* `openDatabase(name)` takes an IndexedDB name scoped to the origin
  (scheme + host + port). `localhost:8080` and `localhost:8081` are different
  origins: use a fixed `--web-port` while debugging or the data "disappears".
* Directory-like names (`'data/my.db'`) are allowed; they are just names.
  `factory.sandbox(path: 'prefix')` from sembast prefixes them. There is no
  file, no `path_provider`, no directory creation.
* Open the database once at startup and keep the `Database`; opening is
  the slow part (the whole database is loaded in memory).
* `deleteDatabase(name)` and `databaseExists(name)` work. Close the database
  in every tab before deleting it: the IndexedDB delete waits for every
  connection to close, it does not complete while another tab has it open.
  `databaseExists` creates an empty IndexedDB database when there is none.
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
* `db.compact()` removes the journal entries of deleted records (also done
  at open); a tab behind a compaction reloads the whole database.

### Data and API limitations

* Keys: `int` or `String` only, as in sembast. Auto-increment int keys and
  generated string keys work.
* Values: the sembast types (`String`, `num`, `bool`, `null`,
  `Map<String, Object?>`, `List<Object?>`, `Timestamp`, `Blob`). `DateTime`
  is still rejected (`ArgumentError`) and a `Uint8List` is stored as a plain
  list of ints: use `Timestamp` and `Blob`.
* IndexedDB stores numbers as JavaScript doubles, with WASM builds too:
  values and keys above 2^53 come back rounded once read from IndexedDB
  (another tab, the next open). Store 64-bit ids as `String`.
* `Timestamp` round-trips at microsecond precision on the VM but the
  platform `DateTime` only has millisecond precision on JavaScript; do not
  rely on sub-millisecond values in web code.
* `codec:` works (sync codecs and `AsyncContentCodecBase`): the records are
  stored encoded and the signature is checked at open. The codec ships with
  the app, so browser-side encryption gives no real protection: keep secrets
  off the client.
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

### Flutter: pick the factory with kIsWeb

```dart
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast_web/sembast_web.dart';

/// Opens the app database on mobile, desktop and web.
Future<Database> openAppDatabase() async {
  if (kIsWeb) {
    // On the web the path is the IndexedDB database name.
    return databaseFactoryWeb.openDatabase('my_app.db');
  }
  // Private app folder (not the user's Documents folder on desktop).
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  return databaseFactoryIo.openDatabase(join(dir.path, 'my_app.db'));
}
```

### Factory selection with a conditional import

The io file is the default, the web file is used when `dart:js_interop`
exists (JavaScript and WASM builds), so `path_provider` and `dart:io` stay
out of the web build.

`lib/db/open_db.dart`:

```dart
export 'open_db_io.dart' if (dart.library.js_interop) 'open_db_web.dart';
```

`lib/db/open_db_io.dart` (Flutter, with `path_provider`; a Dart program
uses a folder of its choice):

```dart
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

/// Opens the app database on Android, iOS, macOS, Windows and Linux.
Future<Database> openAppDatabase(String name) async {
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  return databaseFactoryIo.openDatabase(join(dir.path, name));
}
```

`lib/db/open_db_web.dart`:

```dart
import 'package:sembast_web/sembast_web.dart';

/// Opens the app database on the web, [name] is the IndexedDB database name.
Future<Database> openAppDatabase(String name) =>
    databaseFactoryWeb.openDatabase(name);
```

Usage, identical on every platform:

```dart
import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';

import 'db/open_db.dart';

/// The app database, opened once in main().
late final Database db;

Future<void> main() async {
  // Needed before calling path_provider in main().
  WidgetsFlutterBinding.ensureInitialized();
  db = await openAppDatabase('my_app.db');
  runApp(const MyApp());
}
```

To use `sembast_sqflite` on mobile, open the database in the io file with a
top-level `final factory = getDatabaseFactorySqflite(sqflite.databaseFactory);`
instead of `databaseFactoryIo` (`sembast-sqflite-setup` skill).

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
* Treating the database name as a file path (`path_provider` does not work
  on the web).
* Opening the database in each widget or call instead of once at startup.
* Running non-idempotent code inside `db.transaction` (network calls,
  counters in closures): it can execute twice on the web.
* Debugging Flutter web on a random port and losing the IndexedDB data.
* Storing 64-bit integers or `DateTime` values; use `String` ids and
  `Timestamp`.
* Copying old 1.x code (`db.put(value, key)`, `db.getStore`, `Store`,
  `Record`): rewrite it with `StoreRef` (`sembast-database-setup` skill).
* Relying on browser storage as the only copy of important data.
