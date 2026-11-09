---
name: sembast-database-setup
description: >-
  Use when starting with, opening, configuring, migrating, testing or
  exporting a package:sembast database, or fixing old sembast code: which
  factory per platform (databaseFactoryIo from sembast_io.dart for Dart VM
  and Flutter mobile/desktop, databaseFactoryWeb from sembast_web,
  newDatabaseFactoryMemory / databaseFactoryMemory for tests,
  sembast_sqflite), the database folder (path_provider
  getApplicationSupportDirectory vs getApplicationDocumentsDirectory), one
  Flutter code base for mobile, desktop and web (kIsWeb or conditional
  import), opening once and keeping the Database, version/onVersionChanged
  migrations, DatabaseMode, close, deleteDatabase, sandbox(), SembastCodec
  encryption, exportDatabase / importDatabase, databaseMerge, the removed
  1.x API (db.put, db.get, db.getStore, Store, Record, findRecords,
  Filter.equal), common pitfalls (opening twice, DateTime, read only maps,
  db in a transaction), unit tests and disableSembastCooperator.
---

# sembast: opening, migrating and managing a database

A sembast database is opened through a `DatabaseFactory`; the factory decides
where and how data is stored. The whole database is loaded in memory on open,
so open it once at startup and keep a single `Database` instance for the
application lifetime.

```dart
import 'package:path/path.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> openAppDatabase(String dir) async {
  // sembast_io.dart re-exports sembast.dart and provides databaseFactoryIo.
  return databaseFactoryIo.openDatabase(join(dir, 'app.db'), version: 1);
}
```

## Guidelines

### Choosing the factory (platform)

| Platform | Package, import | Factory |
|---|---|---|
| Dart VM (CLI, server), Flutter Android, iOS, macOS, Windows, Linux | `sembast`, `package:sembast/sembast_io.dart` | `databaseFactoryIo` |
| Web, Flutter web (JS and WASM) | `sembast_web`, `package:sembast_web/sembast_web.dart` | `databaseFactoryWeb` |
| Unit tests (nothing saved) | `sembast`, `package:sembast/sembast_memory.dart` | `newDatabaseFactoryMemory()`, `databaseFactoryMemory` |
| Flutter, stored in SQLite, cross process safe | `sembast_sqflite` + `sqflite` | `getDatabaseFactorySqflite(sqflite.databaseFactory)` |

* The rest of the API (stores, records, queries, transactions, listeners)
  is the same with every factory.
* `databaseFactoryIo`: one JSON-lines file per database, pure Dart, no
  plugin. Not cross-process and not cross-isolate safe: use it from the main
  isolate only.
* `databaseFactoryWeb`: IndexedDB, cross-tab safe (`sembast-web-setup`
  skill). `databaseFactoryIo` compiles on the web but throws
  `UnimplementedError` when used; `databaseFactoryWeb` compiles on io and
  throws there.
* `sembast_sqflite` (`sembast-sqflite-setup` skill): several processes on
  the same file. The git package `tekartik_app_flutter_sembast` (not on
  pub.dev) has a `getDatabaseFactory()` that picks sembast_web on the web
  and sembast_sqflite elsewhere.
* Tests and mocks: `newDatabaseFactoryMemory()` (a fresh isolated factory)
  or `openNewInMemoryDatabase()` (an always-empty database) from
  `package:sembast/sembast_memory.dart`. `databaseFactoryMemory` is a shared
  global memory factory: databases with the same path are the same database
  until closed. `databaseFactoryMemoryFs` simulates the io file format in
  memory (useful to test import/export or `compact`).
* `createDatabaseFactoryIo(rootPath: dir)` makes relative paths resolve under
  `dir`. `anyFactory.sandbox(path: dir)` does the same for any factory (io,
  memory, web) and rejects paths escaping the sandbox. `factory.pathContext`
  gives the `path.Context` used and `factory.hasStorage` is false for
  memory.

### Dependencies

* Dart: `dart pub add sembast`. Flutter: `flutter pub add sembast
  path_provider path`, plus `sembast_web` when the app targets the web.
  Avoid copying version numbers from old tutorials; `pub add` takes the
  latest.

### Opening once

* `factory.openDatabase(path, {version, onVersionChanged, mode, codec})`
  loads everything in memory: open once at startup (in `main()` before
  `runApp`, or lazily behind a single cached `Future<Database>`) and pass
  the same `Database` everywhere. Never open/close around each operation.
* Opening a path already open (same factory) returns the same instance; its
  `version` and `onVersionChanged` are ignored and a `close()` anywhere
  closes it for every user. Two processes, two isolates or two io factories
  writing one file lose data.
* `mode` defaults to `DatabaseMode.neverFails` (create if missing, delete
  and recreate when corrupted). Others: `create` (create if missing, fail on
  corruption), `existing` (fail when missing), `empty` (wipe content),
  `readOnly` (fail when missing, no writes).
* `db.version`, `db.path`, `await db.close()`. Close before deleting:
  `factory.deleteDatabase(path)`; `factory.databaseExists(path)` checks.
* On Flutter, wrap the open in `disableSembastCooperator()` /
  `enableSembastCooperator()` if the splash screen should not yield, and call
  `disableSembastCooperator()` once in `flutter_test` files (the cooperator's
  `Future.delayed` can hang there).
* Size guidance: io below ~100K records / 100 MB, web below ~30K records.
  Open time grows with record count.

### Database folder

* Dart VM: any path, absolute or relative to the current directory. Missing
  parent folders are created by the io factory.
* Flutter: never a relative path. Use `path_provider`
  `getApplicationSupportDirectory()` joined with `package:path` `join`
  (`await dir.create(recursive: true)` is harmless). It is a private app
  folder everywhere: Android `files`, iOS `Library/Application Support`
  (backed up, hidden), macOS `~/Library/Application Support/<bundle id>`
  (inside the container when sandboxed, no entitlement needed), Windows
  `%APPDATA%\<company>\<product>` (from `windows/runner/Runner.rc`), Linux
  `~/.local/share/<application id>`.
* Avoid `getApplicationDocumentsDirectory()` for new apps: on Windows, Linux
  and macOS it is the user's Documents folder; on iOS it is visible in the
  Files app when file sharing is enabled. An existing app that already uses
  it must keep it (or move the file): a new path is a new, empty database.
* Call `WidgetsFlutterBinding.ensureInitialized()` before `path_provider`
  in `main()`. `path_provider` is not available in `flutter test`: use the
  memory factory there.
* Web: no folder, the path is the IndexedDB database name.

### One code base for mobile, desktop and web

* Both `package:sembast/sembast_io.dart` and
  `package:sembast_web/sembast_web.dart` import on every platform, so in
  Flutter a `kIsWeb` test picks the factory; resolve the folder only on io
  (example below).
* Without Flutter, or to keep `path_provider` out of the web build, use a
  conditional import: `export 'open_db_io.dart' if (dart.library.js_interop)
  'open_db_web.dart';` (example in the `sembast-web-setup` skill).

### Versioning and migrations

* A database created without `version` has version 1. Pass a constant
  `version` from day one: on creation `onVersionChanged(db, 0, version)` is
  called, on later upgrades `onVersionChanged(db, oldVersion, newVersion)`.
  It is not called when the versions match.
* Inside `onVersionChanged` use the `db` argument freely (`store.add(db,
  ...)`, `db.transaction(...)`): those calls join the transaction opened for
  the migration, and the new version is stored only when the callback
  succeeds.
* Write migrations as `if (oldVersion < N)` steps in increasing order so a
  fresh install (oldVersion 0) runs every step. Seed data (initial records)
  belongs in the `oldVersion == 0` branch.
* Sembast is schema-less: renaming a field means reading, transforming and
  putting records back; changing key type means copying into a new store
  and `oldStore.drop(db)`.
* Lowering `version` is not an error; `onVersionChanged` is called with
  `oldVersion > newVersion`.

### Codec and encryption

* `SembastCodec(signature: 'name', codec: myCodec)` where `myCodec` is a
  `Codec<Object?, String>` turning a JSON-encodable value into a single-line
  string. Pass it to every `openDatabase` of that database; opening with a
  different codec throws `DatabaseException` with code
  `DatabaseException.errInvalidCodec`. The signature is stored (encoded by
  the codec itself) so a wrong password is detected at open.
* Sembast ships no cipher. Bring your own (for example on top of
  `pointycastle`); the repository's `sembast_test/lib/encrypt_codec.dart`
  is a demonstration only, not production grade.
* A codec calling a plugin or async API: extend `AsyncContentCodecBase`,
  implement `decodeAsync`/`encodeAsync` and pass it as `codec`.
* The codec cannot be changed later. To encrypt an existing database:
  `exportDatabase` it, `importDatabase(export, factory, newPath, codec:
  codec)`, then delete the old one (or `databaseMerge` between two open
  databases).
* Custom value types are handled by `JsonEncodableCodec` type adapters
  (`package:sembast/utils/type_adapter.dart`); `sembastCodecDefault` already
  handles `Timestamp` and `Blob`. Do not write adapters for models: store
  maps.

### Export, import, maintenance

* `package:sembast/utils/sembast_import_export.dart`: `exportDatabase(db,
  {storeNames})` returns a JSON-encodable map, `importDatabase(map, factory,
  path, {codec, storeNames})` creates (after deleting) a database from it and
  returns it open. `exportDatabaseLines` / `importDatabaseLines` /
  `exportLinesToJsonlString` are a line-based format friendlier to git;
  `importDatabaseAny` accepts either format, a JSON string or a list of
  strings. `package:sembast/utils/import_export_io.dart` adds
  `exportDatabaseToJsonlFile` and `importDatabaseFromFile` on the VM.
* `package:sembast/utils/database_utils.dart`: `getNonEmptyStoreNames(db)`
  (there is no other way to list stores) and `databaseMerge(db,
  sourceDatabase: other, storeNames: [...])` which makes `db` content equal
  to `other`.
* `db.compact()` rewrites the io file dropping obsolete lines (automatic
  when 20% of lines are obsolete). `db.checkForChanges()` reloads external
  changes on web/sqflite. `db.reload()` / `db.reOpen()` reread the io file
  (unsafe if writes are in progress).
* `DatabaseException.code` values: `errBadParam`, `errDatabaseNotFound`,
  `errInvalidCodec`, `errDatabaseClosed` (using a closed database).

### The removed 1.x API

The 1.x API (removed in 2.3.0) is still in old tutorials and generated code;
it does not compile. Stores and records are now references holding no data,
and every call takes the `Database` (or the `Transaction`) first.

| Old 1.x code | Current code |
|---|---|
| `db.put(value, key)`, `db.get(key)` | `StoreRef.main().record(key).put(db, value)`, `.get(db)` |
| `Store store = db.getStore('pets')` | `final store = intMapStoreFactory.store('pets')` (or `stringMapStoreFactory`, `StoreRef<K, V>('pets')`) |
| `store.put(value)` (generated key) | `store.add(db, value)` |
| `store.put(value, key)`, `store.get(key)` | `store.record(key).put(db, value)`, `store.record(key).get(db)` |
| `store.update(value, key)`, `store.delete(key)` | `store.record(key).update(db, value)`, `store.record(key).delete(db)` |
| `db.putRecord(Record(store, value, key))` | `store.record(key).put(db, value)` |
| `store.getRecord(key)` (`Record`) | `store.record(key).getSnapshot(db)` (`RecordSnapshot`) |
| `store.findRecords(finder)`, `store.findRecord(finder)` | `store.find(db, finder: finder)`, `store.findFirst(db, finder: finder)` |
| `store.count(filter)`, `store.containsKey(key)` | `store.count(db, filter: filter)`, `store.record(key).exists(db)` |
| `store.clear()`, `db.deleteStore('pets')` | `store.delete(db)`, `store.drop(db)` |
| `db.storeNames` | `getNonEmptyStoreNames(db)` (`utils/database_utils.dart`) |
| `txn.put(...)`, `txn.getStore(...)` | the calls above with `txn` instead of `db` |
| `Filter.equal`, `Filter.notEqual` | `Filter.equals`, `Filter.notEquals` |
| `record['f'] = v` on a read record | `cloneMap(snapshot.value)`, modify, `put` it |
| `ioDatabaseFactory`, `memoryDatabaseFactory` | `databaseFactoryIo`, `databaseFactoryMemory` |

`Finder`, `SortOrder`, `Boundary` and the other `Filter` constructors are
unchanged. Full table: `doc/new_api.md` in the package repository.

## Examples

### Flutter: single global database opened at startup

```dart
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

Future<Database>? _db;

/// The app database, opened on the first call only.
Future<Database> getDatabase() => _db ??= _openDatabase();

Future<Database> _openDatabase() async {
  // Private app folder (not the user's Documents folder on desktop).
  var dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  var dbPath = join(dir.path, 'my_app.db');
  return databaseFactoryIo.openDatabase(dbPath, version: 1);
}
```

### Flutter: one code base for mobile, desktop and web

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
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  return databaseFactoryIo.openDatabase(join(dir.path, 'my_app.db'));
}
```

Call it once from `main()` after `WidgetsFlutterBinding.ensureInitialized()`
and keep the result (a global, a provider, a service locator).

### Dart VM script with a sandboxed factory

```dart
import 'package:sembast/sembast_io.dart';

Future<void> main() async {
  // All relative paths live under .local/db
  var factory = databaseFactoryIo.sandbox(path: '.local/db');
  var db = await factory.openDatabase('cache.db');
  var store = StoreRef<String, int>.main();
  await store.record('runs').put(db, (await store.record('runs').get(db) ?? 0) + 1);
  print(await store.record('runs').get(db));
  await db.close();
}
```

### Versioned migrations with seed data

```dart
import 'package:sembast/sembast.dart';

const kDbVersion = 3;
final productStore = stringMapStoreFactory.store('product');

Future<Database> openWithMigrations(DatabaseFactory factory, String path) {
  return factory.openDatabase(
    path,
    version: kDbVersion,
    onVersionChanged: (db, oldVersion, newVersion) async {
      // oldVersion is 0 on creation: every step below runs.
      if (oldVersion < 1) {
        await productStore.record('demo_1').put(db, {'name': 'Demo 1', 'price': 10});
      }
      if (oldVersion < 2) {
        // Price change shipped in app version 2.
        await productStore.record('demo_1').update(db, {'price': 15});
      }
      if (oldVersion < 3) {
        // Tag every product whose name contains 'demo'.
        await productStore.update(
          db,
          {'tag': 'demo'},
          finder: Finder(
            filter: Filter.custom(
              (record) => (record['name'] as String).toLowerCase().contains('demo'),
            ),
          ),
        );
      }
    },
  );
}
```

### Migrate int keys to String keys in a new store

```dart
import 'package:sembast/sembast.dart';

final fruitStoreV1 = intMapStoreFactory.store('fruit');
final fruitStore = stringMapStoreFactory.store('fruit_v2');

Future<Database> openFruits(DatabaseFactory factory, String path) {
  return factory.openDatabase(
    path,
    version: 2,
    onVersionChanged: (db, oldVersion, newVersion) async {
      if (oldVersion == 1) {
        await db.transaction((txn) async {
          var values = (await fruitStoreV1.find(txn)).values.toList();
          await fruitStore.addAll(txn, values);
          await fruitStoreV1.drop(txn);
        });
      }
    },
  );
}
```

### Unit test with an in-memory factory

```dart
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  test('put/get', () async {
    var factory = newDatabaseFactoryMemory();
    var db = await factory.openDatabase('test.db');
    var record = StoreRef<String, String>.main().record('key');
    await record.put(db, 'value');
    expect(await record.get(db), 'value');
    await db.close();

    // Or an always-empty database in one call:
    var db2 = await openNewInMemoryDatabase();
    expect(await record.get(db2), isNull);
    await db2.close();
  });
}
```

### Custom (async) codec and wrong-codec detection

```dart
import 'dart:convert';

import 'package:sembast/sembast.dart';

/// Demo only: reverses the JSON text. Replace with real encryption.
class ReverseCodec extends AsyncContentCodecBase {
  String _reverse(String text) => text.split('').reversed.join();

  @override
  Future<Object?> decodeAsync(String encoded) async =>
      jsonDecode(_reverse(encoded));

  @override
  Future<String> encodeAsync(Object? input) async =>
      _reverse(jsonEncode(input));
}

Future<Database> openEncoded(DatabaseFactory factory, String path) async {
  var codec = SembastCodec(signature: 'reverse_v1', codec: ReverseCodec());
  try {
    return await factory.openDatabase(path, codec: codec);
  } on DatabaseException catch (e) {
    if (e.code == DatabaseException.errInvalidCodec) {
      // Existing file written with another codec (or password).
      rethrow;
    }
    rethrow;
  }
}
```

### Convert an existing database to an encrypted one

```dart
import 'package:sembast/utils/sembast_import_export.dart';

Future<Database> migrateToCodec(
  DatabaseFactory factory,
  SembastCodec codec,
) async {
  const plainPath = 'my_database.db';
  const encryptedPath = 'my_database_encrypted.db';
  if (await factory.databaseExists(plainPath)) {
    var plainDb = await factory.openDatabase(plainPath);
    var export = await exportDatabase(plainDb);
    await plainDb.close();
    var db = await importDatabase(export, factory, encryptedPath, codec: codec);
    await factory.deleteDatabase(plainPath);
    return db;
  }
  return factory.openDatabase(encryptedPath, codec: codec);
}
```

### Backup and restore as JSON lines (VM)

```dart
import 'package:sembast/sembast_io.dart';
import 'package:sembast/utils/import_export_io.dart';

Future<void> backup(Database db) =>
    exportDatabaseToJsonlFile(db, 'backup/app.jsonl');

Future<Database> restore() =>
    importDatabaseFromFile('backup/app.jsonl', databaseFactoryIo, 'restored.db');
```

## Common mistakes

* Opening the database in several places, on every screen or around each
  call. Keep one instance; opening is the expensive operation, and a second
  open of the same path silently ignores its `version`.
* Using `databaseFactoryIo` in a Flutter web build (runtime
  `UnimplementedError`), or `databaseFactoryMemory` in production.
* A relative path such as `'app.db'` in a Flutter app, or
  `getApplicationDocumentsDirectory()` on desktop (the user's Documents
  folder). Use `getApplicationSupportDirectory()`.
* Changing the folder of an existing app: the users get an empty database.
* Calling `path_provider` in `main()` before
  `WidgetsFlutterBinding.ensureInitialized()`.
* Writing 1.x code (`db.put(value, key)`, `db.getStore`, `Store`, `Record`,
  `findRecords`, `Filter.equal`): see the table above.
* Not awaiting writes, or using `db` instead of `txn` inside a transaction
  (a write deadlocks, a read misses the pending changes).
* Storing a `DateTime` (`ArgumentError`): use `Timestamp`, an `int` or an
  ISO 8601 `String`. Modifying a map read from the database
  (`StateError: read only`): `cloneMap` it first.
* Opening without `version` then adding one later: the existing database is
  already at version 1, so creation logic guarded by `oldVersion == 0` never
  runs for old installs. Handle `oldVersion == 1` too.
* Doing migration writes with a different `Database` object than the `db`
  passed to `onVersionChanged`.
* Changing the codec of an existing database in place. Export and import.
* Deleting the database file directly while it is open; call `db.close()`
  then `factory.deleteDatabase(path)`.

## More

See [references/factories.md](references/factories.md) for the factory,
`DatabaseMode`, codec and import/export listings.
