---
name: sembast-test-setup
description: >-
  Use when validating a sembast DatabaseFactory implementation (io, web,
  sqflite, idb, a custom jdb backend) against the shared sembast conformance
  suites of package:sembast_test: DatabaseTestContext, DatabaseTestContextJdb,
  DatabaseTestContextFs, DatabaseTestContextIo, memoryDatabaseContext,
  databaseTestContextJdbMemory, memoryFsDatabaseContext, databaseContextIo,
  createDatabaseContextIo, all_test.dart defineTests, all_jdb_test.dart
  defineJdbTests, all_fs_test.dart, allIoGroup, setupForTest, deleteForTest,
  dbPathFromName, reOpen, hasStorage, getExistingDatabaseVersion, and the
  demonstration codecs getEncryptSembastCodec, EncryptedDatabaseFactory,
  SembastBase64Codec, MyJsonCodec.
---

# sembast_test: the shared sembast conformance test suites

`package:sembast_test` holds the test suites `sembast` itself runs, packaged as
`defineTests(context)` functions instead of `main()`. Any package that provides
a sembast `DatabaseFactory` (`sembast_web`, `sembast_sqflite`, an `idb_shim`
journal backend, your own storage) wires its factory into a
`DatabaseTestContext` and gets the whole CRUD / query / transaction / listener /
codec / import-export suite for free.

## Guidelines

### Depending on it

* Not on pub.dev (`publish_to: none`). Add it as a **dev dependency**, from git:
  ```yaml
  dev_dependencies:
    sembast_test:
      git:
        url: https://github.com/tekartik/sembast.dart
        path: sembast_test
    test:
  ```
  The README still shows `ref: dart2_3`; that is a legacy branch. Real
  consumers (`sembast_sqflite_common_test`, `tekartik_sembast_flutter`) depend
  on the default branch with no `ref:`.
* It is a test-only package: never import it from `lib/` of a shipped package.
  The one exception is a `*_test` helper package that re-exports contexts for
  its own consumers (see `sembast_sqflite_common_test`).

### Imports

* `package:sembast_test/test_common.dart` is the single import for a suite
  file: it declares `DatabaseTestContext` and re-exports
  `package:test/test.dart` (`group`, `test`, `expect`, `setUp`…), the sembast
  v2 API (`Database`, `DatabaseFactory`, `StoreRef`, `Finder`, `Filter`,
  `SembastCodec`…) and the helpers of `src/test_defs.dart`. You normally do
  not need to import `package:test/test.dart` or `package:sembast/sembast.dart`
  next to it.
* Suite entry points, each in its own library, imported **with a prefix**
  because several of them declare `defineTests`:
  * `package:sembast_test/all_test.dart` → `defineTests(DatabaseTestContext)`
    — the main suite (crud, database, store, record, find, transaction, key,
    listener, open, exception, value, query, sort, doc, codec, import/export,
    records, persistent change listeners).
  * `package:sembast_test/all_jdb_test.dart` →
    `defineJdbTests(DatabaseTestContextJdb)` — journal-database backends
    (format, codec, concurrency). Needs a factory implementing
    `DatabaseFactoryJdb`.
  * `package:sembast_test/all_fs_test.dart` →
    `defineTests(DatabaseTestContextFs)` — on-disk file format and codec.
    Needs a factory implementing `DatabaseFactoryFs`.
  * `package:sembast_test/all_io_test.dart` →
    `allIoGroup(DatabaseTestContextIo)` — `dart:io` import/export, VM only.
* Single suites are importable one by one
  (`crud_test.dart`, `find_test.dart`, `query_test.dart`,
  `transaction_test.dart`, `listener_test.dart`, `open_test.dart`,
  `codec_test.dart`, `database_import_export_test.dart`…), each exposing
  `defineTests(ctx)` (a few use a longer name: `defineRecordTests`,
  `defineQueryTests`, `defineDatabaseClientTests`,
  `defineJdbDatabaseFormatTests`, `defineJdbConcurrentDatabaseTests`). Use them
  to bisect a failure, not as the normal entry point.

### Contexts

* `DatabaseTestContext` has one mutable field, `factory`, plus
  `deleteAndOpen(path, {version, codec})` and `open(path, {version, codec})`.
  Build one with `DatabaseTestContext()..factory = myFactory`.
* Ready-made contexts:
  `memoryDatabaseContext` (`test_common.dart`),
  `databaseTestContextJdbMemory` (`jdb_test_common.dart`),
  `memoryFsDatabaseContext` (`fs_test_common.dart`),
  `databaseContextIo` and `createDatabaseContextIo({rootPath})`
  (`io_test_common.dart`, VM only),
  `memoryFileSystemContext` / `fileSystemContextIo` /
  `createFileSystemContextIo({rootPath})` for the `FileSystemTestContext`
  based format tests.
* Subclasses expose the backend object: `DatabaseTestContextJdb.jdbFactory`,
  `DatabaseTestContextFs.fs`. They cast `factory`, so give them a factory of
  the matching kind or the getter throws.
* A context is stateful only through `factory`; one context can be shared by
  several `define*Tests` calls in the same `main()`, as the sembast tests do.

### Helpers (from `test_common.dart`)

* `setupForTest(ctx, name, {codec})` deletes and opens a database at
  `dbPathFromName(name)` = `.dart_tool/sembast/test/<name>`; `deleteForTest(ctx,
  name)` only deletes and returns that path. Always go through them so runs
  are reproducible and paths stay inside `.dart_tool`.
* `reOpen(db, {mode})` closes and reopens the same database with the same
  codec — the standard way to assert that data survived a restart.
* `hasStorage(factory)` is false for the pure memory factory; `hasStorageJdb(
  factory)` is true for a `DatabaseFactoryJdb`. Guard persistence assertions
  with them so one suite can run on memory and on disk.
* `getExistingDatabaseVersion(factory, path)` opens with
  `DatabaseMode.existing`, reads `version`, closes.
* `isRunningAsJavascript` / `isJavascriptVm` / `kSembastDartIsWeb` skip
  VM-only expectations in a browser run; `TestException` is a throwaway
  exception; `readContent` / `writeContent` read and write a sembast
  `FileSystem` as lines; `devPrintJson(map)` pretty-prints.
* `package:sembast_test/fs_test_common.dart` adds `fsExportToStringList`,
  `fsExportToMapList` and `fsImportFromMapList` to inspect or forge the
  on-disk JSON-lines format;
  `package:sembast_test/jdb_test_common.dart` adds `jdbImportFromMap` and
  `jdbDatabaseImportFromMap` to preload a journal database.
* `package:sembast_test/test_common_impl.dart` exposes
  `getDatabaseExportStat(db)` (line/obsolete-line counts) for compaction tests.

### Codec helpers

* `package:sembast_test/encrypt_codec.dart`:
  `getEncryptSembastCodec(password: ...)` returns a `SembastCodec` with
  signature `encrypt` (Salsa20 from `pointycastle`, md5-derived key, random
  8-byte IV), and `EncryptedDatabaseFactory(databaseFactory: ..., password:
  ...)` wraps any factory so every `openDatabase` uses that codec (passing
  `codec:` to it asserts). The source says it explicitly: demonstration only,
  unauthenticated, weak key derivation — copy it as a starting point, do not
  ship it.
* `package:sembast_test/base64_codec.dart`: `SembastBase64Codec` and
  `SembastBase64CodecAsync` (an `AsyncContentCodecBase`) — obfuscation, not
  encryption, and the async one is the template for a codec calling a plugin.
* `package:sembast_test/test_codecs.dart`: `MyJsonCodec`, `MyCustomCodec`,
  `MyCustomRandomCodec` (adds a random seed, so two encodings of the same
  value differ), `MyJsonCodecDecoderThrow`, `MyJsonCodecEncoderThrow` — fixture
  codecs for error paths.

### Running and troubleshooting

* `dart test` for a VM factory, `dart test -p chrome` for a web factory
  (`build_test` / `build_web_compilers` are needed in the consumer for
  browser runs). A test file targeting the VM starts with `@TestOn('vm')` +
  `library;`.
* The suites are strict: they assume auto-incremented `int` keys per store,
  `String` keys, `Timestamp`/`Blob` support, transactions, `onSnapshot`
  listeners and `deleteDatabase`/`databaseExists`. A partial factory fails
  loudly; run `all_test.dart` first and only add `all_jdb_test.dart` /
  `all_fs_test.dart` when the corresponding interface is really implemented.
* Several suites use `implementation_imports` of `package:sembast`
  (`src/api/v2/...`, `src/database_impl.dart`). That is deliberate for this
  package; do not copy the pattern into application code.
* Expect the suites to create files under `.dart_tool/sembast/test/`; clean
  that directory when a format test misbehaves.

## Examples

### Full suite against your own factory

```dart
@TestOn('vm')
library;

import 'package:sembast/sembast_io.dart';
import 'package:sembast_test/all_test.dart' as all_test;
import 'package:sembast_test/test_common.dart';

void main() {
  // Any DatabaseFactory: databaseFactoryIo, databaseFactoryWeb,
  // getDatabaseFactorySqflite(...), your own implementation.
  var ctx = DatabaseTestContext()..factory = databaseFactoryIo;
  group('my_factory', () {
    all_test.defineTests(ctx);
  });
}
```

### Journal (jdb) backend: main suite plus the jdb suite

```dart
@TestOn('vm')
library;

import 'package:idb_shim/idb_io.dart';
import 'package:idb_shim/idb_jdb.dart';
import 'package:sembast_test/all_jdb_test.dart' as all_jdb_test;
import 'package:sembast_test/all_test.dart' as all_test;
import 'package:sembast_test/jdb_test_common.dart';
import 'package:sembast_test/test_common.dart';

Future<void> main() async {
  var jdbFactory = JdbFactoryIdb(
    getIdbFactorySembastIo('.dart_tool/sembast_test/idb'),
  );
  // DatabaseTestContextJdb exposes ctx.jdbFactory to the jdb suite.
  var ctx = DatabaseTestContextJdb()..factory = DatabaseFactoryJdb(jdbFactory);
  group('idb_io', () {
    all_test.defineTests(ctx);
    all_jdb_test.defineJdbTests(ctx);
  });
}
```

### File-system backend: main, fs and io suites

```dart
@TestOn('vm')
library;

import 'package:sembast_test/all_fs_test.dart' as all_fs_test;
import 'package:sembast_test/all_io_test.dart';
import 'package:sembast_test/all_test.dart' as all_test;
import 'package:sembast_test/io_test_common.dart';
import 'package:test/test.dart';

void main() {
  // rootPath keeps every database of this run in one sandbox directory.
  var ctx = createDatabaseContextIo(rootPath: '.dart_tool/sembast_test/io');
  all_test.defineTests(ctx);
  all_fs_test.defineTests(ctx); // on-disk format and codec
  allIoGroup(ctx); // dart:io import/export
}
```

### Own test using the context helpers

```dart
import 'package:sembast/sembast_memory.dart';
import 'package:sembast_test/test_common.dart';

void main() {
  var ctx = DatabaseTestContext()..factory = newDatabaseFactoryMemory();
  var record = StoreRef<String, Object?>.main().record('key');

  test('value survives a reopen', () async {
    // Deletes then opens .dart_tool/sembast/test/my_app/basic.db
    var db = await setupForTest(ctx, 'my_app/basic.db');
    await record.put(db, 'value');
    db = await reOpen(db);
    // Memory factories have no storage: skip the persistence expectation.
    if (hasStorage(ctx.factory)) {
      expect(await record.get(db), 'value');
    }
    await db.close();
  });
}
```

### Encrypted database with the demonstration codec

```dart
import 'package:sembast/sembast_memory.dart';
import 'package:sembast_test/encrypt_codec.dart';
import 'package:sembast_test/test_common.dart';

void main() {
  var store = StoreRef<int, String>.main();

  test('encrypt codec', () async {
    var factory = newDatabaseFactoryMemory();
    // Demonstration cipher only; do not ship it as is.
    var codec = getEncryptSembastCodec(password: 'user_password');
    var db = await factory.openDatabase('encrypted.db', codec: codec);
    await store.add(db, 'secret');
    expect(await store.record(1).get(db), 'secret');
    await db.close();
  });

  test('factory wrapper applies the codec to every open', () async {
    var factory = EncryptedDatabaseFactory(
      databaseFactory: newDatabaseFactoryMemory(),
      password: 'user_password',
    );
    // Do not pass codec: here, the wrapper asserts it is null.
    var db = await factory.openDatabase('wrapped.db');
    await store.add(db, 'secret');
    await db.close();
  });
}
```

### A `*_test` helper package for your own backend

```dart
import 'package:sembast/sembast_memory.dart';
import 'package:sembast_test/all_test.dart' as all_test;
import 'package:sembast_test/test_common.dart';

/// Context published by your own `my_backend_test` package.
class MyBackendTestContext extends DatabaseTestContext {
  MyBackendTestContext() {
    factory = newDatabaseFactoryMemory(); // your factory here
  }
}

/// Consumers call this from a single test file.
void defineMyBackendTests(MyBackendTestContext ctx) {
  all_test.defineTests(ctx);

  test('backend specific behavior', () async {
    var db = await setupForTest(ctx, 'my_backend/extra.db');
    expect(db.version, 1);
    await db.close();
  });
}
```

## Common mistakes

* Importing two `all_*_test.dart` libraries without a prefix: `defineTests` is
  declared by several of them.
* Passing a plain `DatabaseTestContext` to `defineJdbTests` / the fs suite, or
  a non-jdb factory to `DatabaseTestContextJdb`: the getter cast throws.
* Adding `sembast_test` to `dependencies` instead of `dev_dependencies`.
* Hard-coding database paths instead of `setupForTest` / `dbPathFromName`,
  which leaves files outside `.dart_tool` and breaks reruns.
* Asserting persistence on `databaseFactoryMemory` (use `hasStorage`) or
  running `all_io_test.dart` in a browser (`@TestOn('vm')` only).
* Shipping `getEncryptSembastCodec` / `EncryptedDatabaseFactory` in an app:
  it is an unauthenticated demonstration cipher.
