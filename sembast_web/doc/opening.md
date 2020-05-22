# Opening a database on the web

A `sembast_web` database is an indexed db database.

You need to use the proper database factory (`databaseFactoryWeb` and not `databaseFactoryIo` whic are for IO apps). The path
is just a name in the indexedDB namespace (i.e. based on location too), it is not a path to an absolute/relative file on the 
local file system.

```dart
import 'package:sembast_web/sembast_web.dart';
import 'package:sembast/sembast.dart';

/// Open a database on the web
Future<Database> openDatabaseWeb(String dbName) {
  return databaseFactoryWeb.openDatabase(dbName);
}

Future main() async {
  var db = await openDatabaseWeb('my_app.db');

  // ...
}
```

If you have a flutter app with an already used database factory (`databaseFactoryIo`, `databaseFactorySqflite`) and 
you want to add web support, the easiest is with conditional imports and initialization (factory, path)
 on each platform (Web, Mobile).