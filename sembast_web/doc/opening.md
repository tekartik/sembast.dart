# Opening a database on the web

A `sembast_web` database is an indexed db database.

You need to use the proper database factory (`databaseFactoryWeb` and not `databaseFactoryIo` which is for IO apps). The path
is just a name in the indexedDB namespace (i.e. based on location too), it is not a path to an absolute/relative file on the 
local file system. There is no `path_provider` and no folder to create on the web.

```dart
import 'package:sembast_web/sembast_web.dart';

/// Open a database on the web
Future<Database> openDatabaseWeb(String dbName) {
  return databaseFactoryWeb.openDatabase(dbName);
}

Future main() async {
  var db = await openDatabaseWeb('my_app.db');

  // ...
}
```

Open the database once at startup and keep the `Database` object for the lifetime of the app.

If you have a flutter app with an already used database factory (`databaseFactoryIo`, `databaseFactorySqflite`) and 
you want to add web support, the easiest is with conditional imports and initialization (factory, path)
 on each platform (Web, Mobile).

In a Flutter app, a `kIsWeb` test is enough since `sembast_web.dart` and `sembast_io.dart` can both be imported on
every platform:

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

The conditional import version is in
[One code base for all platforms](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/open.md#one-code-base-for-all-platforms).
