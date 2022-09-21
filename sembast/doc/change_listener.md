## Listen to changes

### Listen to record changes

You can listen to specific record changes

```dart
// Track record changes
var subscription = record.onSnapshot(db).listen((snapshot) {
  // if snapshot is null, the record is not present or has been
  // deleted

  // ...
});

// ...

// cancel subscription. Important! not doing this might lead to
// memory leaks
unawaited(subscription?.cancel());
```


### Listen to store or query result changes

You can listen to changes for a given query in a store

```dart
// Track query changes
var query = store.query(finder: finder);
var subscription = query.onSnapshots(db).listen((snapshots) {
  // snapshots always contains the list of records matching the query

  // ...
});

// ...

// cancel subscription. Important! not doing this might lead to
// memory leaks
unawaited(subscription?.cancel());
```

You can listen to all changes in a store

```dart
// Track every store changes
var query = store.query();
var subscription = query.onSnapshots(db).listen((snapshots) {
  // snapshots always contains the list of all records

  // ...
});
```