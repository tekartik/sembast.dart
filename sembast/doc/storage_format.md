# Sembast storage format

Storage format is optimized for performance. It can also easily be read but not is optimized for size.
Data is stored in a text file where each line is (json format) either:
- meta information of the database (first line)
- record data

Each data written is appended lazily to the file for best performance.

Application should not rely on the file format that could evolve in the future. As of now, any evolution has handled
compatibility on previous file formats and the plan is to continue to do so. 

## Compacting

The file is open in append-mode only so deleted/modified records might look duplicated in the stored file. When the
file is compacted, the obsolete lines get removed.

Compact might happen at any moment to prevent record duplication in the stored file. The whole compact information
is done in a new file followed by a rename to make it atomic.

Compacting has a cost so there is a dumb algorithm to tell when to update the stored file. 
As of v1 the rule is following:
- There are at least 6 records
- There are 20% of obsolete lines to delete

Practically I would say that the overhead in size should max at 20%.

## Import/Export

There are methods to import/export the database.
As of v1, the export is a jsonified Map (not optimized). Application should not rely on the inner format of 
the exported data that should only be consumed as a Map by `importDatabase`.

## Example

Let's insert/update some data:

```dart
// Our shop store sample data
var store = intMapStoreFactory.store('shop');

int lampKey;
int chairKey;
await db.transaction((txn) async {
  // Add 2 records
  lampKey = await store.add(txn, {'name': 'Lamp', 'price': 10});
  chairKey = await store.add(txn, {'name': 'Chair', 'price': 15});
});

// update the price of the lamp record
await store.record(lampKey).update(db, {'price': 12});
```
If you look at the file stored you might see content like this

```json
{"version":1,"sembast":1}
{"key":1,"store":"shop","value":{"name":"Lamp","price":10}}
{"key":2,"store":"shop","value":{"name":"Chair","price":15}}
{"key":1,"store":"shop","value":{"name":"Lamp","price":12}}
```

So you might say that there is an extra record. Actually only the last one is visible to the application and if you 
continue adding data the content might get compacted to only contains

```json
{"version":1,"sembast":1}
{"key":1,"store":"shop","value":{"name":"Lamp","price":12}}
{"key":2,"store":"shop","value":{"name":"Chair","price":15}}
```

You can export the content using 

```dart
var content = await exportDatabase(db);
// Save as text
var saved = jsonEncode(content);
```

As of v1, it would be:

```json
{
  "sembast_export": 1,
  "version": 1,
  "stores": [
    {
      "name": "shop",
      "keys": [
        1,
        2
      ],
      "values": [
        {
          "name": "Lamp",
          "price": 12
        },
        {
          "name": "Chair",
          "price": 15
        }
      ]
    }
  ]
}
```

To import the content in a new database, you can do:

```dart
// Import the data
var map = jsonDecode(saved) as Map;
var importedDb = await importDatabase(map, databaseFactory, 'imported.db');

// Check the lamp price
expect((await store.record(lampKey).get(importedDb))['price'], 12);
```