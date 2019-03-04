# Queries

Let's consider the following data

```dart
// Store some objects
dynamic key1, key2, key3;
await db.transaction((txn) async {
  key1 = await txn.put({'name': 'fish'});
  key2 = await txn.put({'name': 'cat'});
  key3 = await txn.put({'name': 'dog'});
});
```

## Get by key

You can get a record by key

```dart
// Read by key
expect(await db.get(key1), {'name': 'fish'});

// Read 2 records by key
var records = await db.getRecords([key2, key3]);
expect(records[0].value, {'name': 'cat'});
expect(records[1].value, {'name': 'dog'});
```
 

## Filtering and sorting

Filtering and sorting can be done on any field

```dart
// Look for any animal "greater than" (alphabetically) 'cat'
// ordered by name
var finder = Finder(
  filter: Filter.greaterThan('name', 'cat'),
  sortOrders: [SortOrder('name')]);
var records = await db.findRecords(finder);

expect(records.length, 2);
expect(records[0]['name'], 'dog');
expect(records[1]['name'], 'fish');
```

### Sorting by key

Records can be sorted by key using the special `Field.key` field:

```dart
// Look for the last created record
var finder = Finder(sortOrders: [SortOrder(Field.key, false)]);
var record = await db.findRecord(finder);

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

### Using boundaries for paging

`start` and `end` can specify a start and end boundary, similar to firestore

```dart
// Look for the one after `cat`
var finder = Finder(
  sortOrders: [SortOrder('name', true)],
  start: Boundary(values: ['cat']));
var record = await db.findRecord(finder);
expect(record['name'], 'dog');
```

The boundary can be a record. If `values` is used, the number of values should match the number of sort orders

```dart
dynamic key1, key2, key3, key4;
await db.transaction((txn) async {
  key2 = await txn.put({'name': 'Lamp', 'price': 10});
  key3 = await txn.put({'name': 'Chair', 'price': 10});
  key4 = await txn.put({'name': 'Deco', 'price': 5});
  key1 = await txn.put({'name': 'Table', 'price': 35});
});

 // Look for object after Chair 10 (ordered by price then name) so
// should the the Lamp 10
var finder = Finder(
    sortOrders: [SortOrder('price'), SortOrder('name')],
    start: Boundary(values: [10, 'Chair']));
var record = await db.findRecord(finder);
expect(record['name'], 'Lamp');

// You can also specify to look after a given record
finder = Finder(
    sortOrders: [SortOrder('price'), SortOrder('name')],
    start: Boundary(record: record));
record = await db.findRecord(finder);
// After the lamp the more expensive one is the Table
expect(record['name'], 'Table');
```

### Filtering using RegExp patten

Records can be filtered using regular expressions

```dart
// Look for any name stating with f (i.e. fish, frog...)
var finder = Finder(filter: Filter.matches('name', '^f'));
var record = await db.findRecord(finder);

expect(record['name'], 'fish');
```

```dart
// Look for any name ending with og (i.e. dog, frog...)
var finder = Finder(filter: Filter.matches('name', r'og$'));
var record = await db.findRecord(finder);

expect(record['name'], 'dog');
```

```dart
// Look for any name containing 'is' (fish matches)
var finder = Finder(filter: Filter.matches('name', 'is'));
var record = await db.findRecord(finder);

expect(record['name'], 'fish');
```