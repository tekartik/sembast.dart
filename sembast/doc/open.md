# Opening a database

## Opening a database

A database is a single file represented by a path in the file system.

```dart
// File path to a file in the current directory
String dbPath = 'sample.db';
DatabaseFactory dbFactory = databaseFactoryIo;

// We use the database factory to open the database
Database db = await dbFactory.openDatabase(dbPath);
```

The db object is ready for use.

### Flutter

On flutter you need to find a proper location for the database. One solution is to use the `path_provider` package get
 a directory in which you want to create the database.

```dart
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

...

// get the application documents directory
var dir = await getApplicationDocumentsDirectory();
// make sure it exists
await dir.create(recursive: true);
// build the database path
var dbPath = join(dir.path, 'my_database.db');
// open the database
var db = await databaseFactoryIo.openDatabase(dbPath);
```

### Flutter Web

On flutter web, [`sembast_web`](https://pub.dev/packages/sembast_web) should be used.

## Database migration

Like in some other databases (sqflite, indexed_db), the database has a version that the app can use to perform migrations
between application releases. When specifying a `version` during `openDatabase`, the callback `onVersionChanged` is called if the version
differs from the existing.

Practically the version is a constant for an application version and is used to eventually
change some data to match the new expected format.

```dart
// Open the database with version 1
db = await factory.openDatabase(path, version: 1);

// ...

await db.close();

// Open the database with version 2 and perform the migration changes
db = await factory.openDatabase(path, version: 2, onVersionChanged: (db, oldVersion, newVersion) {
  if (oldVersion == 1) {
    // Perform changes before the database is opened
    
    // ...
  }
});
```

See complete migration example [here](migration_example.md).

## Preloading data

The basic versioning system can also be used to preload data. Data must be inserted record by record, coming
from another database (or asset in flutter) or from a custom format.

```dart
// Our shop store sample data
var store = intMapStoreFactory.store('shop');

var db = await factory.openDatabase(path, version: 1,
    onVersionChanged: (db, oldVersion, newVersion) async {
  // If the db does not exist, create some data
  if (oldVersion == 0) {
    await store.add(db, {'name': 'Lamp', 'price': 10});
    await store.add(db, {'name': 'Chair', 'price': 15});
  }
});
```