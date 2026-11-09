# Sembast for the web

[![pub package](https://img.shields.io/pub/v/sembast_web.svg)](https://pub.dev/packages/sembast_web)

[sembast](https://pub.dev/packages/sembast) for the Web, NoSQL persistent embedded database for the Web on top of IndexedDB.

Works on browser applications and flutter web applications (js/wasm). 

* Basic [sembast_web demo](https://github.com/alextekartik/flutter_app_example/tree/master/demo_sembast) on flutter.
* [notepad_sembast](https://github.com/alextekartik/flutter_app_example/tree/master/notepad_sembast): Simple flutter notepad on all platforms
  ([online demo](https://alextekartik.github.io/flutter_app_example/notepad_sembast/))

`sembast_web` only provides the database factory for the web, `databaseFactoryWeb`. The API to read and write data
is the [sembast](https://pub.dev/packages/sembast) API, the same on every platform.

## Getting started

| Platform | Factory |
|---|---|
| Web, Flutter web (JavaScript and WebAssembly builds) | `databaseFactoryWeb` (this package) |
| Web worker | `databaseFactoryWebWorker` (this package) |
| Dart VM, Flutter Android, iOS, macOS, Windows, Linux | `databaseFactoryIo` (`package:sembast/sembast_io.dart`) |
| Unit tests | `newDatabaseFactoryMemory()` (`package:sembast/sembast_memory.dart`) |

Add the dependencies:

```sh
dart pub add sembast sembast_web
# or in a Flutter app
flutter pub add sembast sembast_web
```

Open the database, then use the sembast API (`package:sembast_web/sembast_web.dart` exports it):

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

* Keys are `int` or `String`, as in sembast.
* Content is synchronized across all open tabs (and web workers) of the same origin.
* Transactions are cross-tab safe (since 0.1.0+4).
* Transactions must be idempotent (i.e. they must produce the same result if run twice) as they might run again in case of concurrent access.
* Codecs (`openDatabase(codec: ...)`, sync or async) are supported: the records are stored encoded and the codec
  signature is checked at open. The codec and its key ship with the web app, so this is no strong protection: keep
  secrets off the client.
* JavaScript and WebAssembly builds (`dart:js_interop`, since 2.3.0). `sembast_web_html.dart` only holds a deprecated
  alias of the same `databaseFactoryWeb`: import `sembast_web.dart`.

### Pitfalls

* IndexedDB stores numbers as JavaScript doubles, on WebAssembly too: an `int` above 2^53 comes back rounded from
  IndexedDB (in another tab, or at the next open). Store such ids as a `String`.
* A `DateTime` value throws an `ArgumentError` and a `Uint8List` is read back as a list of ints: use the sembast
  `Timestamp` (`package:sembast/timestamp.dart`) and `Blob` (`package:sembast/blob.dart`) types.
* `deleteDatabase(name)` waits until every connection to that IndexedDB database is closed: it does not complete while
  another tab still has the database open. Close it everywhere first.

### Use the same web port when debugging

The database is stored in the browser indexeddb. Like any other web storage, it is tied to the port. (i.e. localhost:8080 is different from localhost:8081).
When debugging, you should use the same port to keep the same indexeddb database
(for example `flutter run -d chrome --web-port 8080`).

## How it works

Like sembast the whole database is loaded into memory from indexedDB. It notifies cross tabs
using `BroadcastChannel`. data is incrementally updated from indexedDB. If a transaction is ran after
some changes happens, new data is loaded and transaction is ran again.

The only API of its own is `databaseFactoryWeb` (and `databaseFactoryWebWorker` for web workers), the rest is the
sembast API that `sembast_web.dart` exports. For more information on the API see
[sembast](https://pub.dev/packages/sembast) documentation.

### More information

- [Opening a web database](https://github.com/tekartik/sembast.dart/blob/master/sembast_web/doc/opening.md)
- [Some implementation details](https://github.com/tekartik/sembast.dart/blob/master/sembast_web/doc/implementation_details.md)
