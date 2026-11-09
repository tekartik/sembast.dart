# sembast.dart

sembast db stands for
**S**imple **Emb**edded **A**pplication **St**ore **d**ata**b**ase

[![pub package](https://img.shields.io/pub/v/sembast.svg)](https://pub.dev/packages/sembast)
[![Run CI](https://github.com/tekartik/sembast.dart/actions/workflows/run_ci.yml/badge.svg)](https://github.com/tekartik/sembast.dart/actions/workflows/run_ci.yml)

## General

Yet another NoSQL persistent store database solution for single process io applications.
The whole document based database resides in a single file and is loaded in memory when opened. Changes are appended right away to the 
file and the file is automatically compacted when needed.

Works on Dart VM and Flutter (no plugin needed, 100% Dart so works on all platforms - MacOS/Android/iOS/Linux/Windows). Inspired from IndexedDB, DataStore, WebSql, NeDB, Lawndart...

Supports encryption using user-defined codec.

* Pure dart single file IO VM/Flutter storage supported.
* Web support (including Flutter Web) through [`sembast_web`](https://pub.dev/packages/sembast_web).
* Can work on top of sqflite through [`sembast_sqflite`](https://pub.dev/packages/sembast_sqflite).

Usage example: [notepad_sembast](https://github.com/alextekartik/flutter_app_example/tree/master/notepad_sembast): Simple flutter notepad working on all platforms (web/mobile/desktop)
 ([online demo](https://alextekartik.github.io/flutter_app_example/notepad_sembast/))

Follow the [guide](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/guide.md).

## Getting started

1. Add the dependency and pick the factory of your platform.
2. Pick the database location: a file path on io (a folder from `path_provider` in Flutter), a name
   on the web.
3. Open the database once at startup and keep the `Database` object.
4. Read and write records in stores, passing the database to each call.
5. Close the database when done.

### Pick the factory for your platform

A `DatabaseFactory` opens the databases. Only the factory depends on the platform, the rest of the
API (stores, records, queries, transactions) is the same everywhere.

| Platform | Package | Import | Factory |
|---|---|---|---|
| Dart VM (CLI, server), Flutter Android, iOS, macOS, Windows, Linux | `sembast` | `package:sembast/sembast_io.dart` | `databaseFactoryIo` |
| Web, Flutter web | [`sembast_web`](https://pub.dev/packages/sembast_web) | `package:sembast_web/sembast_web.dart` | `databaseFactoryWeb` |
| Unit tests (in memory, nothing saved) | `sembast` | `package:sembast/sembast_memory.dart` | `newDatabaseFactoryMemory()` or `databaseFactoryMemory` |
| Flutter, stored in SQLite (cross process safe) | [`sembast_sqflite`](https://pub.dev/packages/sembast_sqflite) | `package:sembast_sqflite/sembast_sqflite.dart` | `getDatabaseFactorySqflite(sqflite.databaseFactory)` |

Add the dependencies:

```sh
# Dart
dart pub add sembast
# Flutter (path_provider and path find the database folder)
flutter pub add sembast path_provider path
# Flutter web too
flutter pub add sembast_web
```

### Open the database once and keep it

Opening a database loads all its content in memory, it is the slow part. Open it once at startup,
keep the `Database` object (a global variable, a singleton, your dependency injection) and use it
everywhere. Do not open and close it around each read or write.

A store is like a table or a collection. It holds records, each one has a key (`int` or `String`)
and a value (often a map). Declare the stores once and pass the database to every call.

```dart
import 'package:sembast/sembast_io.dart';

Future<void> main() async {
  // Open the database: a file path, relative to the current directory here.
  // The file and its folder are created if needed.
  var db = await databaseFactoryIo.openDatabase('.local/my_app.db');

  // A store with int keys and map values.
  var store = intMapStoreFactory.store('animals');

  // add generates the key, put writes the record of a given key.
  var catKey = await store.add(db, {'name': 'cat', 'age': 4});
  await store.record(100).put(db, {'name': 'dog', 'age': 7});

  // Read a record by key.
  var cat = await store.record(catKey).get(db);
  print(cat); // {name: cat, age: 4}

  // Find records: filter and sort.
  var finder = Finder(
    filter: Filter.greaterThan('age', 5),
    sortOrders: [SortOrder('name')],
  );
  var snapshots = await store.find(db, finder: finder);
  for (var snapshot in snapshots) {
    print('${snapshot.key}: ${snapshot.value}'); // 100: {name: dog, age: 7}
  }

  // Update some fields, delete a record.
  await store.record(catKey).update(db, {'age': 5});
  await store.record(100).delete(db);

  // Group writes in a transaction, use txn (not db) inside.
  await db.transaction((txn) async {
    await store.add(txn, {'name': 'fish'});
    await store.add(txn, {'name': 'bird'});
  });

  // Close it when done (end of a script or a test).
  await db.close();
}
```

### Database folder (Flutter)

In a Flutter app, do not use a relative path: put the database in a folder from
[`path_provider`](https://pub.dev/packages/path_provider).

```dart
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

/// Opens the app database. Call it once at startup and keep the result.
Future<Database> openAppDatabase() async {
  // A private folder of the app, on every platform.
  final dir = await getApplicationSupportDirectory();
  // Make sure it exists.
  await dir.create(recursive: true);
  final dbPath = join(dir.path, 'my_app.db');
  return databaseFactoryIo.openDatabase(dbPath);
}
```

* Prefer `getApplicationSupportDirectory()`. On Windows, Linux and macOS,
  `getApplicationDocumentsDirectory()` is the user's Documents folder. On iOS, the Documents folder
  is shown to the user in the Files app when file sharing is enabled.
* An app that already has its database in another folder must keep that path (or move the file):
  a new path opens a new, empty database.
* To open it in `main()` before `runApp`, call `WidgetsFlutterBinding.ensureInitialized()` first.
* On the web there is no folder: the path is the name of the IndexedDB database.

More details per platform in [Opening a database](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/open.md).

### One code base for mobile, desktop and web

`sembast_io.dart` and `sembast_web.dart` can both be imported on every platform (the factory of the
other platform throws an `UnimplementedError` when used). In Flutter, a `kIsWeb` test is enough:

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

Without Flutter, or to keep `path_provider` out of the web build, use a conditional import
(`if (dart.library.js_interop)`), see
[One code base for all platforms](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/open.md#one-code-base-for-all-platforms).

## Old API (1.x) to current API

The 1.x API was removed in 2.3.0 (2020) but it is still in old tutorials and in code written by
AI assistants. It does not compile anymore. Today a store or a record reference holds no data and
the first argument of every call is the `Database` (or the `Transaction`).

| Old 1.x code | Current code |
|---|---|
| `db.put(value, key)`, `db.get(key)` | `StoreRef.main().record(key).put(db, value)`, `.get(db)` |
| `Store store = db.getStore('pets')` | `var store = intMapStoreFactory.store('pets')` |
| `store.put(value)` (generated key) | `store.add(db, value)` |
| `store.put(value, key)` | `store.record(key).put(db, value)` |
| `store.get(key)` | `store.record(key).get(db)` |
| `store.update(value, key)` | `store.record(key).update(db, value)` |
| `store.delete(key)` | `store.record(key).delete(db)` |
| `db.putRecord(Record(store, value, key))` | `store.record(key).put(db, value)` |
| `store.getRecord(key)` (a `Record`) | `store.record(key).getSnapshot(db)` (a `RecordSnapshot`) |
| `store.findRecords(finder)` | `store.find(db, finder: finder)` |
| `store.findRecord(finder)` | `store.findFirst(db, finder: finder)` |
| `store.count(filter)` | `store.count(db, filter: filter)` |
| `store.clear()`, `db.deleteStore('pets')` | `store.delete(db)`, `store.drop(db)` |
| `txn.put(value, key)`, `txn.getStore('pets')` | the calls above with `txn` instead of `db` |
| `Filter.equal`, `Filter.notEqual` | `Filter.equals`, `Filter.notEquals` |
| `record['name'] = 'x'` on a read record | `var map = cloneMap(snapshot.value)`, change `map`, put it |

`Finder`, `SortOrder` and the other `Filter` constructors did not change. The full list is in
[Migrating from the 1.x API](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/new_api.md).

## Common pitfalls

* **Opening the database several times.** A second `openDatabase` of the same path returns the
  same open instance and ignores its `version` and `onVersionChanged`, and a `close()` closes it
  for everyone. Two processes or isolates writing the same io file lose data
  ([`sembast_sqflite`](https://pub.dev/packages/sembast_sqflite) is cross process safe).
* **Not awaiting.** Every call is asynchronous: `await` it, otherwise the next line runs before
  the write is done and its error escapes your `try`/`catch`.
* **Using `db` inside a transaction.** Use the `txn` argument for every call. A write with `db`
  waits for the transaction, which waits for the write: deadlock. A read with `db` does not see
  the changes of the transaction.
* **Storing a `DateTime`.** It throws an `ArgumentError`. Store a `Timestamp`
  (`package:sembast/timestamp.dart`, `Timestamp.fromDateTime(dateTime)`, `timestamp.toDateTime()`),
  an `int` (`millisecondsSinceEpoch`) or an ISO 8601 `String`. For bytes (`Uint8List`), use a `Blob`
  (`package:sembast/blob.dart`).
* **Keys other than `int` or `String`.** Only `int` keys (generated by `add` in an
  `intMapStoreFactory` store) and `String` keys (generated in a `stringMapStoreFactory` store) are
  supported.
* **Modifying a value read.** Maps and lists returned by `get`, `find` and the snapshots are read
  only (`StateError: read only`). Copy them first with `cloneMap` or `cloneList` from
  `package:sembast/utils/value_utils.dart`.
* **Storing your own classes.** Values are JSON like (`Map<String, Object?>`, `List`, `String`,
  `num`, `bool`): convert your objects to and from maps.

More in [Troubleshooting](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/troubleshooting.md).

## Usage

### Reading and writing records

Simple example of writing and reading records

```dart
// dynamically typed store
var store = StoreRef.main();
// Easy to put/get simple values or map
// A key can be of type int or String and the value can be anything as long as it can
// be properly JSON encoded/decoded
await store.record('title').put(db, 'Simple application');
await store.record('version').put(db, 10);
await store.record('settings').put(db, {'offline': true});

// read values
var title = await store.record('title').get(db) as String;
var version = await store.record('version').get(db) as int;
var settings = await store.record('settings').get(db) as Map;
  
// ...and delete
await store.record('version').delete(db);
```

### Store

The store has some similarities with IndexedDB store and DataStore entities. The database always has a main store for easy access (like in the example aboves or typically to save singletons) and allows
for an infinite number of stores where a developer would store entity specific data (such as a list of records of the same 'type')

```dart
 // Use the animals store using Map records with int keys
var store = intMapStoreFactory.store('animals');

// Store some objects
await db.transaction((txn) async {
  await store.add(txn, {'name': 'fish'});
  await store.add(txn, {'name': 'cat'});
  
  // You can specify a key
  await store.record(10).put(txn, {'name': 'dog'});
});

```

The API takes advantage of Dart strong mode to make database access less error prone.

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

More info on the store API [here](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/new_api.md)

When record values are of type Map, record fields can be referenced using a dot (.) unless escaped.

```dart
var store = intMapStoreFactory.store();
var key = await store.add(db, {'path': {'sub': 'my_value'}, 'with.dots': 'my_other_value'});

var record = await store.record(key).getSnapshot(db);
var value = record['path.sub'];
// value = 'my_value'
var value2 = record[FieldKey.escape('with.dots')];
// value2 = 'my_other_value'
```

Follow the links for more information on how to [write](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/writes.md)
or [read](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/queries.md) data

### Auto increment

If no key is provided, the object is inserted with an auto-increment value

```dart
var store = StoreRef<int, String>.main();
// Auto incrementation is built-in
var key1 = await store.add(db, 'value1');
var key2 = await store.add(db, 'value2');
// key1 = 1, key2 = 2...
```

### Transaction

Actions can be grouped into transactions for consistency and optimization (single write on the file system). 
If an error is thrown, the transaction is cancelled and the changes reverted.

Inside the transaction, use the `txn` object for every call, never `db`: a write with `db`
waits for the transaction to end (deadlock).

```dart
await db.transaction((txn) async {
  await store.add(txn, 'value1');
  await store.add(txn, 'value2');
});
```

More info on transaction [here](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/transactions.md)

### Simple find mechanism

Filtering and sorting can be done on any field

More information [here](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/queries.md).

```dart
 // Use the animals store using Map records with int keys
var store = intMapStoreFactory.store('animals');

// Store some objects
await db.transaction((txn) async {
  await store.add(txn, {'name': 'fish'});
  await store.add(txn, {'name': 'cat'});
  await store.add(txn, {'name': 'dog'});
});

// Look for any animal "greater than" (alphabetically) 'cat'
// ordered by name
var finder = Finder(
    filter: Filter.greaterThan('name', 'cat'),
    sortOrders: [SortOrder('name')]);
var records = await store.find(db, finder: finder);

expect(records.length, 2);
expect(records[0]['name'], 'dog');
expect(records[1]['name'], 'fish');
```

### Listen to changes

Similarly to firestore, you can asynchronously listen to record, store or query changes.

More information [here](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/change_listener.md)

### Triggers

For data integrity, you can also track changes during transaction and perform additional operations
in the same transaction

More information [here](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/triggers.md)

### Codec and encryption

Sembast supports using a user-defined codec to encode/decode data when read/written to disk.
It provides a way to support encryption. Encryption itself is not part of sembast but an example of a simple
encryption codec is provided in the test folder.

```dart
// Initialize the encryption codec with a user password
var codec = getEncryptSembastCodec(password: '[your_user_password]');

// Open the database with the codec
Database db = await factory.openDatabase(dbPath, codec: codec);

// ...your database is ready to use

```

More information [here](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/codec.md).

## Information

### Storage format

Data is stored in a text file where each line is (json format) either:
- meta information of the database (first line)
- record data

Each data written is appended lazily to the file for best performance. Compact might happen at any moment
to prevent record duplication. The whole compact information is done in a new file
followed by a rename to make it atomic.

More information [here](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/storage_format.md).

### Supported types

Supported types depends on JSON supported types. More information [here](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/data_types.md)

#### Keys

Supported key types are:
- int (default with autoincrement when no key are passed)
- String (supports generation of unique key)

#### Values

Supported value types are:
- `String`
- `num` (`int` and `double`)
- `Map<String, Object?>` (`Object?` being any of the supported types)
- `List<Object?>` (`Object?` being any of the supported types, `Iterable` is not a supported types, use to `toList()` to convert any iterable)
- `bool`
- `null` (the root record value itself cannot be null though)
- `Blob` (custom type)
- `Timestamp` (custom type)

Map must be of type `Map<String, Object?>`.

`DateTime` is not supported, use `Timestamp` (`Timestamp.fromDateTime(dateTime)`). `Uint8List` is
stored as a list of int, use `Blob`.

The root document data cannot be `null` (but null are accepted for map values, i.e. `{"test": null}`, `[1, null, "test"]` is ok but `null` is not)

### Resources

Third party examples and tutorials available are listed [here](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/resources.md).

### Issue

* [Troubleshooting](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/troubleshooting.md).

## Sponsor or hire

sembast is maintained by Alexandre Roux ([Tekartik](https://tekartik.com/)).

* [Sponsor its maintenance](https://github.com/sponsors/alextekartik) on GitHub Sponsors.
* [Hire me](https://tekartik.com/work-with-me/) for help on your app: local databases, offline-first apps and sync, Flutter and Dart apps and backends.
