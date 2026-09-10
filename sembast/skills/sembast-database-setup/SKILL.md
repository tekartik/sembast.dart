---
name: sembast-database-setup
description: >-
  Use when opening, configuring, migrating, testing or exporting a
  package:sembast database: DatabaseFactory, databaseFactoryIo
  (sembast_io.dart), databaseFactoryMemory / newDatabaseFactoryMemory /
  openNewInMemoryDatabase (sembast_memory.dart), openDatabase path, version and
  onVersionChanged migrations, DatabaseMode, close, deleteDatabase, the
  factory.sandbox() extension, SembastCodec encryption and async codecs,
  exportDatabase / importDatabase, databaseMerge, choosing sembast_web or
  sembast_sqflite per platform, Flutter path_provider setup, unit tests and
  disableSembastCooperator.
---

# sembast: opening, migrating and managing a database

A sembast database is opened through a `DatabaseFactory`; the factory decides
where and how data is stored. The whole database is loaded in memory on open,
so open it once at startup and keep a single `Database` instance for the
application lifetime.

```dart
import 'package:sembast/sembast_io.dart';

Future<Database> openAppDatabase(String dir) async {
  // sembast_io.dart re-exports sembast.dart and provides databaseFactoryIo.
  return databaseFactoryIo.openDatabase('$dir/app.db', version: 1);
}
```

## Guidelines

### Choosing the factory (platform)

* Dart VM and Flutter mobile/desktop: `databaseFactoryIo` from
  `package:sembast/sembast_io.dart`. One JSON-lines file per database, pure
  Dart, no plugin. Not cross-process and not cross-isolate safe: use it from
  the main isolate only.
* Web and Flutter web: `databaseFactoryWeb` from `package:sembast_web`
  (IndexedDB, cross-tab safe). `databaseFactoryIo` compiles on the web but
  throws `UnimplementedError` at runtime. Select the factory with a
  conditional import (`sembast-web-setup` skill).
* Cross-process safety on VM/Flutter (several processes on the same file):
  `sembast_sqflite` (`getDatabaseFactorySqflite`). The Flutter package
  `tekartik_app_flutter_sembast` bundles a `getDatabaseFactory()` that picks
  the right one per platform.
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

### Opening

* `factory.openDatabase(path, {version, onVersionChanged, mode, codec})`.
  On io `path` is a file path (create the parent directory first, see the
  Flutter example). Opening an already open database returns the same
  instance.
* `mode` defaults to `DatabaseMode.neverFails` (create if missing, delete
  and recreate when corrupted). Others: `create` (create if missing, fail on
  corruption), `existing` (fail when missing), `empty` (wipe content),
  `readOnly` (fail when missing, no writes).
* `db.version`, `db.path`, `await db.close()`. Close before deleting:
  `factory.deleteDatabase(path)`; `factory.databaseExists(path)` checks.
* In Flutter, build the path with `path_provider`
  (`getApplicationDocumentsDirectory()`) and `package:path` `join`. Never
  hard-code a directory. Open in `main()` before `runApp`, or lazily behind a
  single cached `Future<Database>`.
* On Flutter, wrap the open in `disableSembastCooperator()` /
  `enableSembastCooperator()` if the splash screen should not yield, and call
  `disableSembastCooperator()` once in `flutter_test` files (the cooperator's
  `Future.delayed` can hang there).
* Size guidance: io below ~100K records / 100 MB, web below ~30K records.
  Open time grows with record count.

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

## Examples

### Flutter: single global database opened at startup

```dart
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

Database? _db;

Future<Database> getDatabase() async {
  if (_db != null) return _db!;
  var dir = await getApplicationDocumentsDirectory();
  await dir.create(recursive: true);
  var dbPath = join(dir.path, 'my_app.db');
  _db = await databaseFactoryIo.openDatabase(dbPath, version: 1);
  return _db!;
}
```

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

* Opening the database in several places or on every screen. Keep one
  instance; opening is the expensive operation.
* Using `databaseFactoryIo` in a Flutter web build (runtime
  `UnimplementedError`), or `databaseFactoryMemory` in production.
* Forgetting `dir.create(recursive: true)` on Flutter, or using a relative
  path such as `'app.db'` on mobile.
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
