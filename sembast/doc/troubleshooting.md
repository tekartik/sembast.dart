# Troubleshooting

See also the [common pitfalls](https://github.com/tekartik/sembast.dart/blob/master/sembast/README.md#common-pitfalls).

## Compile errors

### `The method 'put' isn't defined for the type 'Database'`

The same for `db.get`, `db.getStore`, `findRecords`, `getRecord` or the `Store` and `Record` classes: this is the
1.x API, removed in 2.3.0. See [Migrating from the 1.x API](new_api.md).

### `The method 'equal' isn't defined for the type 'Filter'`

Or `Member not found: 'Filter.equal'` when running. Use `Filter.equals` (and `Filter.notEquals` for
`Filter.notEqual`).

### `The method 'add' isn't defined for the type 'StoreRef'`

Add `import 'package:sembast/sembast.dart';` (the store and record methods are extensions). If you only show some
names from it, also show the extensions (see [2.4.3 update](#243-update)).

## Runtime errors

### `UnimplementedError: databaseFactoryIo not supported on the web. use sembast_web`

The app runs on the web, use `databaseFactoryWeb` from [`sembast_web`](https://pub.dev/packages/sembast_web). See
[One code base for all platforms](open.md#one-code-base-for-all-platforms).

### `UnimplementedError: databaseFactoryWeb not support on Flutter/VM`

The opposite: `databaseFactoryWeb` only works on the web, use `databaseFactoryIo` (or `sembast_sqflite`) on io.

### `Invalid argument: type DateTime not supported`

A `DateTime` cannot be stored. Store a `Timestamp` from `package:sembast/timestamp.dart`
(`Timestamp.fromDateTime(dateTime)`, read it back with `timestamp.toDateTime()`), an `int` (`millisecondsSinceEpoch`)
or an ISO 8601 `String`. The same error is thrown for
an `Iterable` (call `toList()`) or an object of your own class (convert it to a map).

### `Bad state: read only`

A map or a list read from the database was modified. Values read are immutable, clone them first with `cloneMap`
or `cloneList` from `package:sembast/utils/value_utils.dart`.

### `DatabaseException [3] database is closed`

The database was used after `close()`. Opening the same path twice gives the same instance, so a `close()` in one
part of the app closes it for the others. Open the database once and close it only when the app (or the test) is
done with it.

### `Binding has not yet been initialized` (Flutter)

`path_provider` (or `sqflite`) was called in `main()` before `runApp()`. Call
`WidgetsFlutterBinding.ensureInitialized()` first.

## Other problems

### The app hangs in a transaction

A call inside `db.transaction` uses `db` instead of the `txn` argument, or starts another `db.transaction`: the
call waits for the transaction, which waits for the call. Use `txn` for every call in the transaction.

During development, `debugSembastWarnDatabaseCallInTransaction = true` prints a stack trace and a hint when a
transaction lasts more than 10 seconds.

### The data is lost on the web when debugging

IndexedDB storage belongs to the origin, port included: `localhost:8080` and `localhost:8081` are two different
storages. Use a fixed port, for example `flutter run -d chrome --web-port 8080`.

### The data is lost after an app update (Flutter)

The database path changed, for example after switching from `getApplicationDocumentsDirectory()` to
`getApplicationSupportDirectory()`. A new path opens a new, empty database: keep the old path or move the file.

### Flutter widget tests hang

In `testWidgets`, use the memory factory and call `disableSembastCooperator()`, see [how-to](how_to.md).

## 2.4.3 Update

if you don't `import 'package:sembast/sembast.dart'` or only show some class/methods you might need to add:

```dart
import 'package:sembast/sembast.dart' show SembastStoreRefExtension, SembastRecordRefExtension;
```
