# Queries

Let's consider the following data

```dart
// Store some objects
int key1, key2, key3;
await db.transaction((txn) async {
  key1 = await store.add(txn, {'name': 'fish'});
  key2 = await store.add(txn, {'name': 'cat'});
  key3 = await store.add(txn, {'name': 'dog'});
});
```

## Get by key

You can get a record by key

```dart
   // Read by key
expect(await store.record(key1).get(db), {'name': 'fish'});

// Read 2 records by key
var records = await store.records([key2, key3]).get(db);
expect(records[0], {'name': 'cat'});
expect(records[1], {'name': 'dog'});
```


## Modify a read result

Records you get are immutable/read-only. When using map, it you want to use the resulting map as a base for a 
new object for modification and creation, you should first clone the value:

```dart
import 'package:sembast/utils/value_utils.dart';

 // Read by key
var value = await store.record(key1).get(db);

// read values are immutable/read-only. If you want to modify it you
// should clone it first

// the following will throw an exception
value['name'] = 'nice fish'; // Will throw!

// clone the resulting map for modification
var map = cloneMap(value);
map['name'] = 'nice fish';

// map is ready to be stored
```

## Filtering and sorting

Filtering and sorting can be done on any field

```dart
// Look for any animal "greater than" (alphabetically) 'cat'
// ordered by name
var finder = Finder(
  filter: Filter.greaterThan('name', 'cat'),
  sortOrders: [SortOrder('name')]);
var records = await store.find(db, finder: finder);

expect(records.length, 2);
expect(records[0]['name'], 'dog');
expect(records[1]['name'], 'fish');
```

## Finding first

You can limit your query to the first element found

```dart
// Find the first record matching the finder
var record = await store.findFirst(db, finder: finder);
// Get the record id
var recordId = record.key;
// Get the record value
var recordValue = record.value;
```

## Modify a record found

Records you get are immutable/read-only. When using map, it you want to use the resulting map as a base for a 
new object for modification and creation, you should first clone the value:

```dart
import 'package:sembast/utils/value_utils.dart';

// find a record
var record = await store.findFirst(db, finder: finder);
          
// record snapshot are read-only. 
// If you want to modify it you should clone it
var map = cloneMap(record.value);
map['name'] = 'nice dog';

// map is ready to be stored
```

### Sorting by key

Records can be sorted by key using the special `Field.key` field:

```dart
// Look for the last created record
var finder = Finder(sortOrders: [SortOrder(Field.key, false)]);
var record = await store.findFirst(db, finder: finder);

expect(record['name'], 'dog');
```

### Sorting/querying on nested field

Assuming you have the following record 

```json
{
  "name": "Silver",
  "product": {
    "code": "1F8"
  }
}
```

You can order on product/code

```dart
var finder = Finder(sortOrders: [SortOrder('product.code')]);
```

Or query on it

```dart
var finder = Finder(filter: Filter.equals('product.code', 'AF8'));
```

### Composite filter

You can combine multiple filters using the operators `&` and `|`:

```dart
var filterAnd = Filter.greaterThan(Field.value, "hi") &
    Filter.lessThan(Field.value, "hum");
var filterOr = Filter.lessThan(Field.value, "hi") |
    Filter.greaterThan(Field.value, "hum");
```


If you have more than two filters, you can also use `Filter.or` and `Filter.and`:
```dart
var filter = Filter.and([
  Filter.greaterThan(Field.value, "hi"),
  Filter.lessThan(Field.value, "hum"),
  Filter.notEquals(Field.value, "ho"),
]);
```

### Using boundaries for paging

`start` and `end` can specify a start and end boundary, similar to firestore

```dart
// Look for the one after `cat`
var finder = Finder(
  sortOrders: [SortOrder('name', true)],
  start: Boundary(values: ['cat']));
var record = await store.findFirst(db, finder: finder);
expect(record['name'], 'dog');
```

The boundary can be a record. If `values` is used, the number of values should match the number of sort orders

```dart
// Our shop store
var store = intMapStoreFactory.store('shop');

await db.transaction((txn) async {
  await store.add(txn, {'name': 'Lamp', 'price': 10});
  await store.add(txn, {'name': 'Chair', 'price': 10});
  await store.add(txn, {'name': 'Deco', 'price': 5});
  await store.add(txn, {'name': 'Table', 'price': 35});
});

// Look for object after Chair 10 (ordered by price then name) so
// should the the Lamp 10
var finder = Finder(
  sortOrders: [SortOrder('price'), SortOrder('name')],
  start: Boundary(values: [10, 'Chair']));
var record = await store.findFirst(db, finder: finder);
expect(record['name'], 'Lamp');

// You can also specify to look after a given record
finder = Finder(
  sortOrders: [SortOrder('price'), SortOrder('name')],
  start: Boundary(record: record));
record = await store.findFirst(db, finder: finder);
// After the lamp the more expensive one is the Table
expect(record['name'], 'Table');
```

### Filtering using RegExp patten

Records can be filtered using regular expressions

```dart
// Look for any name stating with f (i.e. fish, frog...)
var finder = Finder(filter: Filter.matches('name', '^f'));
var record = await store.findFirst(db, finder: finder);

expect(record['name'], 'fish');
```

```dart
// Look for any name ending with og (i.e. dog, frog...)
var finder = Finder(filter: Filter.matches('name', r'og$'));
var record = await store.findFirst(db, finder: finder);

expect(record['name'], 'dog');
```

```dart
// Look for any name containing 'is' (fish matches)
var finder = Finder(filter: Filter.matches('name', 'is'));
var record = await store.findFirst(db, finder: finder);

expect(record['name'], 'fish');
```

### Filtering list items

`Filter.equals` and `Filter.matches` can also look for list items if a field is a list using the `anyInList` option. It
will match if one item in the list matches the criteria.

```dart
// Look for record with at least one category stating with f (i.e. food...), 
// if `categories` field is a list with text elements
var finder = Finder(filter: Filter.matches('categories', '^f', anyInList: true));
var record = await store.findFirst(db, finder: finder);
```
