# Sembast for the web

[sembast](https://pub.dev/packages/sembast) for the Web, NoSQL persistent embedded database for the Web on top of IndexedDB.

Works on browser applications and flutter web applications (js/wasm). 

* Basic [sembast_web demo](https://github.com/alextekartik/flutter_app_example/tree/master/demo_sembast) on flutter.
* [notepad_sembast](https://github.com/alextekartik/flutter_app_example/tree/master/notepad_sembast): Simple flutter notepad on all platforms
  ([online demo](https://alextekartik.github.io/flutter_app_example/notepad_sembast/))

## Setup

In pubspec.yaml

```yaml
dependencies:
  sembast_web: '>=1.0.0'
```

## Usage

```dart
import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';

Future main() async {
  // Declare our store (records are mapd, ids are ints)
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

## Features and limitations

* Use int or key string only
* Content is synchronized across all open tabs
* Transactions are cross-tab safe (since 0.1.0+4)
* Codec are not supported. Web is not safe anyway. Encrypt fields as needed.
* Transactions must be idempotent (i.e. they must produce the same result if run twice) as they might run again in case of concurrent access.
* WASM support as of 2.3.0 (legacy html version available through `sembast_web_html.dart` import)

## How it works

Like sembast the whole database is loaded into memory from indexedDB. It notifies cross tabs
using localStorage. data is incrementally updated from indexedDB. If a transaction is ran after
some changes happens, new data is loaded and transaction is ran again.

The only exported API is `databaseFactoryWeb`. For more information on the API see [sembast](https://pub.dev/packages/sembast) documentation.
