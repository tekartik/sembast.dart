# sembast.dart

sembast db stands for
**S**imple **Emb**edded **A**pplication **St**ore **d**ata**b**ase

[![Build Status](https://travis-ci.org/tekartik/sembast.dart.svg?branch=master)](https://travis-ci.org/tekartik/sembast.dart)

## General

Yet another NoSQL persistent store database solution for single process io applications.
The whole document based database resides in a single file and is loaded in memory when opened. Changes are appended right away to the 
file and the file is automatically compacted when needed.

Works on Dart VM and Flutter (no plugin needed, 100% Dart so works on all platforms - MacOS/Android/iOS/Linux/Windows). Inspired from IndexedDB, DataStore, WebSql, NeDB, Lawndart...

Supports encryption using user-defined codec.

* Pure dart single file IO VM/Flutter storage supported.
* Web support (including Flutter Web) through [`sembast_web`](https://pub.dev/packages/sembast_web).
* Can work on top of sqflite through [`sembast_sqflite`](https://pub.dev/packages/sembast_sqflite).

Usage example: [notepad_sembast](https://github.com/alextekartik/flutter_app_example/tree/master/notepad_sembast): Simple flutter notepad working on all platforms (web/mobile/mac)
 ([online demo](https://alextekartik.github.io/flutter_app_example/notepad_sembast/))

Follow the [guide](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/guide.md).

## Usage

### Opening a database

A database is a single file represented by a path in the file system

#### Flutter

On flutter you need to find a proper location for the database. One solution is to use the `path_provider` package get
 a directory in which you want to create the database.

```dart
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

// get the application documents directory
final dir = await getApplicationSupportDirectory();
// make sure it exists
await dir.create(recursive: true);
// build the database path
final dbPath = join(dir.path, 'my_database.db');
// open the database
final db = await databaseFactoryIo.openDatabase(dbPath);
```

#### Dart

```dart
// File path to a file in the current directory
String dbPath = 'sample.db';
DatabaseFactory dbFactory = databaseFactoryIo;

// We use the database factory to open the database
Database db = await dbFactory.openDatabase(dbPath);
```

The db object is ready for use.

More information [here](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/open.md).

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

To prevent deadlock, never use an existing Database or Store object.

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

More information [here](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/new_api.md#listen-to-changes)

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

The root document data cannot be `null` (but null are accepted for map values, i.e. `{"test": null}`, `[1, null, "test"]` is ok but `null` is not)

### Resources

Third party examples and tutorials available are listed [here](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/resources.md).

### Issue

* [Troubleshooting](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/troubleshooting.md).

## Build status

Travis: [![Build Status](https://travis-ci.org/tekartik/sembast.dart.svg?branch=master)](https://travis-ci.org/tekartik/sembast.dart)
