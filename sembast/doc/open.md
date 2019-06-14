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

// 
```