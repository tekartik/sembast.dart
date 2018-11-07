# sembast.dart

sembast db stands for
**S**imple **Emb**edded **A**pplication **St**ore **d**ata**b**ase

[![Build Status](https://travis-ci.org/tekartik/sembast.dart.svg?branch=master)](https://travis-ci.org/tekartik/sembast.dart)

## General

Yet another NoSQL persistent store database solution for single process io applications.
The whole database resides in a single file and is loaded in memory when opened. Changes are appended right away to the 
file and the file is automatically compacted when needed.

Works on Dart VM and Flutter (no plugin needed, 100% Dart). Inspired from IndexedDB, DataStore, WebSql, NeDB, Lawndart...

## Usage

### Opening a database

A database is a single file represented by a path in the file system

```dart
// File path to a file in the same directory than the current script
String dbPath = join(dirname(Platform.script.toFilePath()), "sample.db");
DatabaseFactory dbFactory = databaseFactoryIo;

// We use the database factory to open the database
Database db = await dbFactory.openDatabase(dbPath);
```

The db object is ready for use.

### Simple put/get records

For quick usage, data can be written and read quickly using the put/get/delete api on the database object

```dart
// Easy to put/get simple values or map
// A key can be anything (int, String) as long is it can
// be properly JSON encoded/decoded
await db.put('Simple application', 'title');
await db.put(10, 'version');
await db.put({'offline': true}, 'settings');

// read values
String title = await db.get('title') as String; 
int version = await db.get('version') as int;
Map settings = await db.get('settings') as Map;
  
// ...and delete
await db.delete('version');
```

Follow the links with more informatin on how to [write](https://github.com/tekartik/sembast.dart/blob/master/doc/writes.md)
or [read](https://github.com/tekartik/sembast.dart/blob/master/doc/queries.md) data

### Auto increment

If no key is provided, the object is inserted with an auto-increment value

```dart
// Auto incrementation is built-in
int key1 = await db.put('value1') as int;
int key2 = await db.put('value2') as int;
// key1 = 1, key2 = 2...
```

### Transaction

Actions can be group in transaction for consistency and optimization (single write on the file system). 
If an error is thrown, the transaction is cancelled and the changes reverted.

To prevent deadlock, never use an existing Database or Store object.

```dart
await db.transaction((txn) async {
  await txn.put('value1');
  await txn.put('value2');
});
```

More info on transaction [here](https://github.com/tekartik/sembast.dart/blob/master/doc/transactions.md)

### Simple wrapping into a Record object

A record object holds the record content and key

```dart
int key = await db.put({'offline': true});
Record record = await db.getRecord(key);
  
// A record can be accessed like a map
expect(record['offline'], isTrue);
// and has the key in it
expect(record.key, key);
```

### Simple find mechanism

Filtering and sorting can be done on any field

More information [here](https://github.com/tekartik/sembast.dart/blob/master/doc/queries.md)

```dart
// Store some objects
await db.transaction((txn) async {
  await txn.put({'name': 'fish'});
  await txn.put({'name': 'cat'});
  await txn.put({'name': 'dog'});
});

// Look for any animal "greater than" (alphabetically) 'cat'
// ordered by name
var finder = Finder(
  filter: Filter.greaterThan('name', 'cat'),
  sortOrders: [SortOrder('name')]);
var records = await db.findRecords(finder);

expect(records.length, 2);
expect(records[0]['name'], 'dog');
expect(records[1]['name'], 'fish');
```

### Store

The store has some similarities with IndexedDB store and DataStore entities. The database always has a main store for easy access (like in the example aboves or typically to save singletons) and allows
for an infinite number of stores where a developer would store entity specific data (such as list of record of the same 'type')

```dart
// Access the "animal" store
Store animalStore = db.getStore("animal");
// create animals in the store
var cat = Record(animalStore, {'name': 'cat'});
var dog = Record(animalStore, {'name': 'dog'});
// save them
await db.putRecords([cat, dog]);
  
// get all animals
await animalStore.records.listen((Record animal) {
  // here we know we have a single record
  // .. you'll get dog and cat here
}).asFuture();
```

### idb_shim

The project idb_shim provides a shim allowing accessing it using the IndexedDB api. The benefit is to be able to write the logic/synchronization part of the database layer and 
test its algorithms using Dart VM and not Dartium

```dart
// Idb factory based on sembast
var idbFactory = IdbSembastFactory(databaseFactoryIo);

String store = "my_store";

// Here the indexed db API can be used
void _initializeDatabase(VersionChangeEvent e) {
  Database db = e.database;
  // create a store
  ObjectStore objectStore = db.createObjectStore(store);
}
Database db = await idbFactory.open(dbPath, version: 1, onUpgradeNeeded: _initializeDatabase);

Transaction transaction = db.transaction(store, IDB_MODE_READ_WRITE);
ObjectStore objectStore = transaction.objectStore(store);

// put and read on object
await objectStore.put("value", "test");
expect(await objectStore.getObject("test"), "value");

await transaction.completed;
```

## Information

### Storage format

Data is stored in a text file where each line is (json format) either:
- meta information of the database (first line)
- record data

Each data written is appended to the file for best performance. Compact might happen at any moment
to prevent record duplication. The whole compact information is done in a new file
followed by a rename to make it atomic.

### Supported types

Supported types depends on JSON supported types. More information [here](https://github.com/tekartik/sembast.dart/blob/master/doc/data_types.md)

#### Keys

Supported key types are:
- int (default with autoincrement when no key are passed)
- String
- double

#### Values

Supported value types are:
- String.
- num (int and double)
- Map
- List
- bool
- `null`

## Build status

Travis: [![Build Status](https://travis-ci.org/tekartik/sembast.dart.svg?branch=master)](https://travis-ci.org/tekartik/sembast.dart)
