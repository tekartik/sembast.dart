# Migrating to 1.15.0

As of 1.15.0, there is a new API available to manipulate data in the database. 
Previous API had too many `dynamic` types. Switching to the new API (for now the existing API remains) make it less
error-prone.

The new `Store` API allows you to enforce the type of keys and values:

```dart
// Use the main store for storing key values as String
var store = StoreRef<String, String>.main();

// Writing the data
await store.record('username').put(db, 'my_username');
await store.record('url').put(db, 'my_url');

// Reading the data
var url = await store.record('url').get(db);
var username = await store.record('username').get(db);
```

It also makes access in `Transaction` and `Database` more similar:

```dart
await db.transaction((txn) async {
  url = await store.record('url').get(txn);
  username = await store.record('username').get(txn);
});

```

## Examples

Some examples to migrate your code:

### Put get data

#### Before

```dart
// Cast necessary to manipulate the key
var key = await db.put({'offline': true}) as int;
Record record = await db.getRecord(key);
// Cast necessary to manipulate the data
var value = record.value as Map<String, dynamic>;

```

#### After

```dart
 // Lint warnings will warn you if you try to use different types
var store = intMapStoreFactory.store();
var key = await store.add(db, {'offline': true});
var value = await store.record(key).get(db);

```

### Find


#### Before

```dart
Record record = await db.findRecord(finder);
// Cast necessary to manipulate the data
var value = record.value as Map<String, dynamic>;

```

#### After

```dart
// No cast needed
var value = await store.findFirst(db, finder: finder);

```

## Supported types

`StoreRef<K, V>` supports the following declared types for keys (`K`) and values (`V`)

### Keys

Supported declared key types:
- `int` (default with autoincrement when no key are passed)
- `String` (String keys can also be generated à la firestore)

#### Values

Map must be explicitly of type `Map<String, dynamic>`. This is the most commonly used typed for saving a record with
multiple fields.

Supported value types are:
- String
- int
- num
- double
- bool
- `Map<String, dynamic>`
- `List<dynamic>`

