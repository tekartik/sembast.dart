# sembast_web

[sembast](https://pub.dev/packages/sembast) for the Web - **Preview**

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

* Experimental
* Use int or key string only
* Transactions are not cross-tab safe
