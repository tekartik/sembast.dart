# Opening a database

Opening a database means loading its content in memory. This is an expensive operation. In an application (flutter, web),
the recommended way is to open the database on start and to keep it open during the lifetime of the application.

You should not open a database multiple times and **you should have a single global instance of an opened database.**
A second `openDatabase` of the same path (with the same factory) returns the same open instance: its `version` and
`onVersionChanged` are ignored, and closing it closes it for every user.

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

The factory depends on the platform:

| Platform | Package | Factory |
|---|---|---|
| Dart VM, Flutter Android, iOS, macOS, Windows, Linux | `sembast` (`sembast_io.dart`) | `databaseFactoryIo` |
| Web, Flutter web | [`sembast_web`](https://pub.dev/packages/sembast_web) | `databaseFactoryWeb` |
| Unit tests | `sembast` (`sembast_memory.dart`) | `newDatabaseFactoryMemory()`, `databaseFactoryMemory` |
| Flutter, stored in SQLite | [`sembast_sqflite`](https://pub.dev/packages/sembast_sqflite) | `getDatabaseFactorySqflite(sqflite.databaseFactory)` |

See [Database factory](factory.md).

### Flutter

On flutter you need to find a proper location for the database. Use the
[`path_provider`](https://pub.dev/packages/path_provider) package to get a directory in which you want to create the
database.

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

To open it in `main()` before `runApp()`, call `WidgetsFlutterBinding.ensureInitialized()` first (`path_provider`
is a plugin):

```dart
import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';

/// The app database, opened once in main().
late final Database db;

Future<void> main() async {
  // Needed before calling path_provider in main().
  WidgetsFlutterBinding.ensureInitialized();
  db = await openAppDatabase();
  runApp(const MyApp());
}
```

### Database folder per platform

Prefer `getApplicationSupportDirectory()` to `getApplicationDocumentsDirectory()`: it is a private folder of the app
on every platform, while the documents folder is the user's Documents folder on desktop.

| Platform | `getApplicationSupportDirectory()` | `getApplicationDocumentsDirectory()` |
|---|---|---|
| Android | private app folder (`files`) | private app folder (`app_flutter`) |
| iOS | `Library/Application Support`, backed up, hidden from the user | `Documents`, backed up, visible in the Files app when file sharing is enabled |
| macOS | `~/Library/Application Support/<bundle id>` (inside the app container when sandboxed) | the user's `~/Documents` (the container one when sandboxed) |
| Windows | `%APPDATA%\<company name>\<product name>` | the user's Documents folder |
| Linux | `~/.local/share/<application id>` | the user's `~/Documents` |
| Web | not available | not available |

Notes:

* macOS: the app container is always writable, the support folder needs no sandbox entitlement.
* Windows: the company and product names come from `windows/runner/Runner.rc` (the company is the `--org` of
  `flutter create`, `com.example` by default), set them before the first release.
* An app that already has its database in another folder (often `getApplicationDocumentsDirectory()`) must keep
  that path, or move the file: a new path opens a new, empty database.
* Do not use a relative path in a Flutter app, it depends on the current directory of the process.
* In `flutter test`, there is no `path_provider`: use the memory factory (see [how-to](how_to.md)).

### Dart VM

A command line tool or a server chooses its own path, absolute or relative to the current directory. The parent
folders are created if needed.

### Flutter Web

On flutter web, [`sembast_web`](https://pub.dev/packages/sembast_web) should be used. There is no folder: the path is
the name of the IndexedDB database.

```dart
import 'package:sembast_web/sembast_web.dart';

Future<Database> openAppDatabase() =>
    databaseFactoryWeb.openDatabase('my_app.db');
```

## One code base for all platforms

`package:sembast/sembast_io.dart` and `package:sembast_web/sembast_web.dart` can both be imported on every platform:
`databaseFactoryIo` throws an `UnimplementedError` when used on the web, `databaseFactoryWeb` throws one when used on
io. In a Flutter app, test `kIsWeb`:

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

Without Flutter, or to keep `path_provider` and `dart:io` out of the web build, use a conditional import. The io
file is the default, the web file is used when `dart:js_interop` is available (JavaScript and WebAssembly builds).

`lib/db/open_db.dart`:

```dart
export 'open_db_io.dart' if (dart.library.js_interop) 'open_db_web.dart';
```

`lib/db/open_db_io.dart`:

```dart
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

/// Opens the app database on Android, iOS, macOS, Windows and Linux.
Future<Database> openAppDatabase(String name) async {
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  return databaseFactoryIo.openDatabase(join(dir.path, name));
}
```

`lib/db/open_db_web.dart`:

```dart
import 'package:sembast_web/sembast_web.dart';

/// Opens the app database on the web, [name] is the IndexedDB database name.
Future<Database> openAppDatabase(String name) =>
    databaseFactoryWeb.openDatabase(name);
```

Usage, the same on every platform:

```dart
import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';

import 'db/open_db.dart';

/// The app database, opened once in main().
late final Database db;

Future<void> main() async {
  // Needed before calling path_provider in main().
  WidgetsFlutterBinding.ensureInitialized();
  db = await openAppDatabase('my_app.db');
  runApp(const MyApp());
}
```

In a Dart (non Flutter) program, replace `path_provider` in the io file by a folder of your choice.

The [notepad_sembast](https://github.com/alextekartik/flutter_app_example/tree/master/notepad_sembast) example runs
on all platforms the same way, with a helper package that also uses `sembast_sqflite` on mobile.

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
