# Sembast for the web

**Preview**: [sembast](https://pub.dev/packages/sembast) for the Web, NoSQL persistent embedded database for the Web on top of IndexedDB.

## Setup

In pubspec.yaml

```yaml
dependencies:
  sembast_web: '>=0.1.0'
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
      await store.add(db, <String, dynamic>{'name': 'Table', 'price': 15});

  // Read the record
  var value = await store.record(key).get(db);

  // Print the value
  print(value);

  // Close the database
  await db.close();
}
```

## Features and bugs

* Alpha
* Use int or key string only
* Transactions are cross-tab safe (since 0.1.0+4)
* Codec are not supported. Web is not safe anyway. Encrypt fields as needed.
* Transactions must be indempotent (i.e. they must produce the same result if run twice) as they might run again in case of

## How it works

Like sembast the whole database is loaded into memory from indexeddb. It notifies cross tabs
using localStorage. data is incrementally updated from indexeddb. If a transaction is ran after
some changes happens, new data is loaded and transaction is ran again.
