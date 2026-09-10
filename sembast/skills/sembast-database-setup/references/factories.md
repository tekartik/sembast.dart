# sembast factories, open options and utilities

## DatabaseFactory (`package:sembast/sembast.dart`)

* `Future<Database> openDatabase(String path, {int? version,
  OnVersionChangedFunction? onVersionChanged, DatabaseMode? mode,
  SembastCodec? codec})`
* `Future<void> deleteDatabase(String path)`
* `Future<bool> databaseExists(String path)`
* `bool get hasStorage` (false for memory)
* `p.Context get pathContext`
* Extension `sandbox({required String path})` returns a factory whose paths
  are all below `path` (throws `ArgumentError` for paths escaping it; never
  nests two sandboxes).

`OnVersionChangedFunction = FutureOr<dynamic> Function(Database db, int
oldVersion, int newVersion)`.

## Factory implementations

| Factory | Import | Storage |
|---|---|---|
| `databaseFactoryIo` | `package:sembast/sembast_io.dart` | one JSON-lines file per database (VM, Flutter) |
| `createDatabaseFactoryIo({rootPath})` | `package:sembast/sembast_io.dart` | io factory rooted at `rootPath` |
| `databaseFactoryMemory` | `package:sembast/sembast_memory.dart` | shared in-memory, no storage |
| `newDatabaseFactoryMemory()` | `package:sembast/sembast_memory.dart` | new isolated in-memory factory |
| `openNewInMemoryDatabase({version, onVersionChanged, mode, codec})` | `package:sembast/sembast_memory.dart` | always-blank database (`sembastInMemoryDatabasePath`) |
| `databaseFactoryMemoryFs` | `package:sembast/sembast_memory.dart` | memory simulation of the io file format |
| `databaseFactoryMemoryJdb` | `package:sembast/utils/jdb.dart` | memory simulation of the journal format used by web/sqflite (transactions may re-run) |
| `databaseFactoryWeb` | `package:sembast_web/sembast_web.dart` | IndexedDB |
| `getDatabaseFactorySqflite(sqfliteFactory)` | `package:sembast_sqflite/sembast_sqflite.dart` | SQLite journal, cross-process safe |

## DatabaseMode

| Mode | Behavior |
|---|---|
| `DatabaseMode.neverFails` (default, `defaultMode`) | create if missing; a corrupted database is deleted and recreated |
| `DatabaseMode.create` | create if missing |
| `DatabaseMode.existing` | fail if missing |
| `DatabaseMode.empty` | open and clear all content |
| `DatabaseMode.readOnly` | fail if missing, writes not allowed |

## Database

`int get version`, `String get path`, `Future<T> transaction<T>(action)`,
`Future close()`. `DatabaseExtension`: `compact()`, `checkForChanges()`,
`reOpen()`, `reload()`.

## DatabaseException

`code` and `message`; constants `errBadParam` (0), `errDatabaseNotFound`
(1), `errInvalidCodec` (2), `errDatabaseClosed` (3).

## Codec

* `SembastCodec({required String? signature, required Codec<Object?,
  String>? codec, JsonEncodableCodec? jsonEncodableCodec})`
* `AsyncContentCodecBase` (implement `Future<Object?> decodeAsync(String)`
  and `Future<String> encodeAsync(Object?)`) for asynchronous codecs.
* `sembastCodecDefault`: no content codec, `Timestamp` and `Blob` adapters.
* `sembastCodecWithAdapters(Iterable<SembastTypeAdapter>)`: build a codec with
  custom type adapters (`package:sembast/utils/type_adapter.dart` exports
  `SembastTypeAdapter`, `sembastTimestampAdapter`, `sembastBlobAdapter`,
  `sembastDefaultTypeAdapters`, `JsonEncodableCodec`,
  `sembastCodecToJsonEncodable`, `sembastCodecFromJsonEncodable`).
* `generateStringKey()` (`package:sembast/utils/key_utils.dart`) produces the
  push-id style keys used by `stringMapStoreFactory` stores.

## Import / export (`package:sembast/utils/sembast_import_export.dart`)

* `exportDatabase(Database db, {List<String>? storeNames})` returns
  `Map<String, Object?>` (`{'sembast_export': 1, 'version': n, 'stores':
  [{'name', 'keys', 'values'}]}`).
* `exportDatabaseLines(db, {storeNames})` returns `List<Object>` (meta map,
  then `{'store': name}` followed by `[key, value]` pairs).
* `exportLinesToJsonStringList(lines)`, `exportLinesToJsonlString(lines)`.
* `importDatabase(Map srcData, DatabaseFactory dstFactory, String dstPath,
  {SembastCodec? codec, List<String>? storeNames})`,
  `importDatabaseLines(List, ...)`, `importDatabaseAny(Object, ...)` (map,
  lines, JSON string or list of JSON strings), `decodeImportAny(Object)`.
  Import deletes `dstPath` first and returns the open database.
* VM only (`package:sembast/utils/import_export_io.dart`):
  `exportDatabaseToJsonlFile(db, path, {storeNames})`,
  `importDatabaseFromFile(path, dstFactory, dstPath, {codec, storeNames})`.

## Database utilities (`package:sembast/utils/database_utils.dart`)

* `Iterable<String> getNonEmptyStoreNames(Database db)`
* `Future<void> databaseMerge(Database db, {required Database
  sourceDatabase, List<String>? storeNames})`: after the call `db` holds the
  same records as `sourceDatabase` for the given stores (unchanged records are
  not rewritten, extra records are deleted), in one transaction.
* `db.dropAll()` (`package:sembast/sembast.dart`): delete every store.

## Cooperator

`disableSembastCooperator()` and `enableSembastCooperator({int?
delayMicroseconds, int? pauseMicroseconds})` (`package:sembast/sembast.dart`).
Default: pause 100 microseconds every 4 ms during heavy loops.

## Logging

`debugSembastWarnDatabaseCallInTransaction = true` prints a deadlock hint
when a transaction takes more than 10 s (debug use only).
