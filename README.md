# sembast.dart

sembast db stands for
**S**imple **Emb**edded **A**pplication **St**ore **d**ata**b**ase

[![Build Status](https://travis-ci.org/tekartik/sembast.dart.svg?branch=master)](https://travis-ci.org/tekartik/sembast.dart)

## General

Yet another persistent store database solution for single process io applications.
The whole database resides in a single file and is loaded in memory when opened. Changes are appended right away to the file and the file is automatically compacted when needed.

Inspired from IndexedDB, DataStore, WebSql, NeDB, Lawndart...

## Usage

Sample usage are given using the experimental async/await feature for clarity. Same code can be done using Future

### Opening a database

A database is a single file represented by a path in the file system

    // File path to a file in the same directory than the current script
    String dbPath = join(dirname(Platform.script.toFilePath()), "sample.db");
    DatabaseFactory dbFactory = ioDatabaseFactory;
    
    // We use the database factory to open the database
    Database db = await dbFactory.openDatabase(dbPath);

The db object is ready for use.

### Simple put/get records

For quick usage, data can be written and read quickly using the put/get/delete api on the database object

    // Easy to put/get simple values or map
    // A key can be anything (int, String) as long is it can
    // be properly JSON encoded/decoded
    await db.put('Simple application', 'title');
    await db.put(10, 'version');
    await db.put({'offline': true}, 'settings');
    
    // read values
    String title = await db.get('title'); 
    int version = await db.get('version');
    Map settings = await db.get('settings');
      
    // ...and delete
    await db.delete('version');

### Auto increment

If no key is provided, the object is inserted with an auto-increment value

    // Auto incrementation is built-in
    int key1 = await db.put('value1');
    int key2 = await db.put('value2');
    // key1 = 1, key2 = 2...

### Transaction

Actions can be group in transaction for consistency and optimization (single write on the file system). If an error is thrown, the transaction is cancelled and the changes reverted

    await db.inTransaction(() async {
      await db.put('value1');
      await db.put('value2');
    });

### Simple wrapping into a Record object

A record object holds the record content and key

    int key = await db.put({'offline': true});
    Record record = await db.getRecord(key);
      
    // A record can be accessed like a map
    expect(record['offline'], isTrue);
    // and has the key in it
    expect(record.key, key);

### Simple find mechanism

(Work in progress) Filtering and sorting can be done on any field

    // Store some objects
    await db.inTransaction(() async {
      await db.put({'name': 'fish'});
      await db.put({'name': 'cat'});
      await db.put({'name': 'dog'});
    });
      
    // Look for any animal "greater than" (alphabetically) 'cat'
    // ordered by name
    Finder finder = new Finder();
    finder.filter = new Filter.greaterThan('name', 'cat');
    finder.sortOrder = new SortOrder('name');
    List<Record> records = await db.findRecords(finder);
      
    expect(records.length, 2);
    expect(records[0]['name'], 'dog');
    expect(records[1]['name'], 'fish');

### Store

The store has some similarities with IndexedDB store and DataStore entities. The database always has a main store for easy access (like in the example aboves or typically to save singletons) and allows
for an infinite number of stores where a developer would store entity specific data (such as list of record of the same 'type')

    // Access the "animal" store
    Store animalStore = db.getStore("animal");
    // create animals in the store
    Record cat = new Record(animalStore, {'name': 'cat'});
    Record dog = new Record(animalStore, {'name': 'dog'});
    // save them
    await db.putRecords([cat, dog]);
      
    // get all animals
    await animalStore.records.listen((Record animal) {
      // here we know we have a single record
      // .. you'll get dog and cat here
    }).asFuture();

### idb_shim

The project idb_shim provides a shim allowing accessing it using the IndexedDB api. The benefit is to be able to write the logic/synchronization part of the database layer and 
test its algorithms using Dart VM and not Dartium

    // Idb factory based on sembast
    IdbSembastFactory idbFactory = new IdbSembastFactory(ioDatabaseFactory);
    
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

## Build status

Travis: [![Build Status](https://travis-ci.org/alextekartik/sembast.dart.svg?branch=master)](https://travis-ci.org/alextekartik/sembast.dart)
