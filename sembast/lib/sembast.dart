/// sembast, a NoSQL document database for Dart and Flutter.
///
/// This library holds the API used on every platform: [StoreRef] (a store of
/// records, like a table or a collection), [RecordRef] (one record), [Finder]
/// and [Filter] (queries), [Database] and [Transaction].
///
/// A database is opened with a [DatabaseFactory], which depends on the
/// platform:
///
/// * `databaseFactoryIo` from `package:sembast/sembast_io.dart`: Dart VM and
///   Flutter Android, iOS, macOS, Windows and Linux. One file per database.
/// * `databaseFactoryWeb` from `package:sembast_web/sembast_web.dart`: web
///   and Flutter web (IndexedDB).
/// * `newDatabaseFactoryMemory()` from `package:sembast/sembast_memory.dart`:
///   unit tests, nothing is saved.
///
/// ```dart
/// import 'package:sembast/sembast_io.dart';
///
/// Future<void> main() async {
///   // Open the database once and keep it for the lifetime of the app.
///   var db = await databaseFactoryIo.openDatabase('my_app.db');
///   var store = intMapStoreFactory.store('animals');
///   var key = await store.add(db, {'name': 'cat'});
///   print(await store.record(key).get(db)); // {name: cat}
///   await db.close();
/// }
/// ```
///
/// Every read and write takes the [Database] (or the [Transaction] inside
/// `db.transaction`) as its first argument. The 1.x API (`db.put(value, key)`,
/// `db.getStore(name)`, the `Store` and `Record` classes) no longer exists,
/// see https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/new_api.md
library;

/// The API
export 'package:sembast/src/api/sembast.dart';
