# Sembast for the web

[sembast](https://pub.dev/packages/sembast) for the Web, NoSQL persistent embedded database for the Web on top of IndexedDB.

Works on browser applications and flutter web applications (js/wasm). 

* Basic [sembast_web demo](https://github.com/alextekartik/flutter_app_example/tree/master/demo_sembast) on flutter.
* [notepad_sembast](https://github.com/alextekartik/flutter_app_example/tree/master/notepad_sembast): Simple flutter notepad on all platforms
  ([online demo](https://alextekartik.github.io/flutter_app_example/notepad_sembast/))

`sembast_web` only provides the database factory for the web, `databaseFactoryWeb`. The API to read and write data
is the [sembast](https://pub.dev/packages/sembast) API, the same on every platform.

| Platform | Factory |
|---|---|
| Web, Flutter web | `databaseFactoryWeb` (this package) |
| Dart VM, Flutter Android, iOS, macOS, Windows, Linux | `databaseFactoryIo` (`package:sembast/sembast_io.dart`) |
| Unit tests | `newDatabaseFactoryMemory()` (`package:sembast/sembast_memory.dart`) |

## Setup

```sh
dart pub add sembast sembast_web
# or in a Flutter app
flutter pub add sembast sembast_web
```

## Usage

```dart
import 'package:sembast_web/sembast_web.dart';

Future main() async {
  // Declare our store (records are maps, ids are ints)
  var store = intMapStoreFactory.store();
  var factory = databaseFactoryWeb;

  // Open the database
  var db = await factory.openDatabase('test');

  // Add a new record
  var key =
      await store.add(db, <String, Object?>{'name': 'Table', 'price': 15});

  // Read the record
  var value = await store.record(key).get(db);

  // Print the value
  print(value);

  // Close the database
  await db.close();
}
```

The path given to `openDatabase` is the name of the IndexedDB database, not a file: no `path_provider` and no folder
on the web. Open the database once at startup and keep the `Database` object for the lifetime of the app.

## One code base for the web, mobile and desktop

`package:sembast_web/sembast_web.dart` can be imported on every platform (`databaseFactoryWeb` throws an
`UnimplementedError` when used outside the web), and so can `package:sembast/sembast_io.dart`. In Flutter, test
`kIsWeb`:

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

A conditional import (`if (dart.library.js_interop)`) works without Flutter, see
[One code base for all platforms](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/open.md#one-code-base-for-all-platforms).

## Features and limitations

* Use int or key string only
* Content is synchronized across all open tabs
* Transactions are cross-tab safe (since 0.1.0+4)
* Codec are not supported. Web is not safe anyway. Encrypt fields as needed.
* Transactions must be idempotent (i.e. they must produce the same result if run twice) as they might run again in case of concurrent access.
* WASM support as of 2.3.0 (legacy html version available through `sembast_web_html.dart` import)

### Use the same web port when debugging

The database is stored in the browser indexeddb. Like any other web storage, it is tied to the port. (i.e. localhost:8080 is different from localhost:8081).
When debugging, you should use the same port to keep the same indexeddb database
(for example `flutter run -d chrome --web-port 8080`).

## How it works

Like sembast the whole database is loaded into memory from indexedDB. It notifies cross tabs
using `BroadcastChannel`. data is incrementally updated from indexedDB. If a transaction is ran after
some changes happens, new data is loaded and transaction is ran again.

The only exported API is `databaseFactoryWeb` (and `databaseFactoryWebWorker` for web workers). For more information
on the API see [sembast](https://pub.dev/packages/sembast) documentation.

### More information

- [Opening a web database](https://github.com/tekartik/sembast.dart/blob/master/sembast_web/doc/opening.md)
- [Some implementation details](https://github.com/tekartik/sembast.dart/blob/master/sembast_web/doc/implementation_details.md)
