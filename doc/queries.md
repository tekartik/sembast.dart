# Queries

## Filtering and sorting

Filtering and sorting can be done on any field

```dart
// Store some objects
await db.transaction((txn) async {
  await txn.put({'name': 'fish'});
  await txn.put({'name': 'cat'});
  await txn.put({'name': 'dog'});
});

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

## Sorting by key

Records can be sorted by key using the special `Field.key` field:

```dart
// Look for the last created record
var finder = Finder(sortOrders: [SortOrder(Field.key, false)]);
var record = await db.findRecord(finder);

expect(record['name'], 'dog');
```
