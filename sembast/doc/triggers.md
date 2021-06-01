## Triggers

As of sembast 3.0.1, a trigger like feature is supported. It allows
implementing features like "on delete cascade" to ensure data integrity.

* Triggers are called when records are added, updated or deleted.
* Triggers are called in the same transaction than the one where the record was modified
* A trigger can itself perform other modification that could itself call other triggers
* Like transactions, a trigger must be idempotent, i.e. if for some reason a transaction
  is re-started, pending changes are discarded and triggers will be called again.
* You can set triggers on stores.

### Listen to store changes

You can listen to changes in a store

```dart
// Track record changes
store.addOnChangesListener(db).listen((transaction, changes) async {
  // ...
});
```

In each change:
- `oldSnapshot` is null for item added
- `newSnapshot` is null for item deleted
- none are null for modification

### Example

Create a 'student' and 'enroll' store. A student can enroll a course.

```dart
var studentStore = intMapStoreFactory.store('student');
var enrollStore = intMapStoreFactory.store('enroll');
```

Setup trigger to delete a record in 'enroll' when a student is deleted

```dart
studentStore.addOnChangesListener(db, (transaction, changes) async {
  // For each student deleted, delete the entry in enroll store
  for (var change in changes) {
    // newValue is null for deletion
    if (change.isDelete) {
      // Delete in enroll, use the transaction!
      await enrollStore.delete(transaction,
          finder:
              Finder(filter: Filter.equals('student', change.ref.key)));
    }
  }
});
```

Add some data

```dart
var studentId1 = await studentStore.add(db, {'name': 'Jack'});
var studentId2 = await studentStore.add(db, {'name': 'Joe'});

await enrollStore.add(db, {'student': studentId1, 'course': 'Math'});
await enrollStore.add(db, {'student': studentId2, 'course': 'French'});
await enrollStore.add(db, {'student': studentId1, 'course': 'French'});

// The initial data in enroll is
expect((await enrollStore.find(db)).map((e) => e.value), [
  {'student': 1, 'course' : 'Math'},
  {'student': 2, 'course': 'French'},
  {'student': 1, 'course': 'French'}
]);

```

Delete the student. It will trigger the listener and the entries in the enroll
store will be deleted.

```dart
await studentStore.record(studentId1).delete(db);

// Data has been deleted in 'enroll' store too!
expect((await enrollStore.find(db)).map((e) => e.value), [
  {'student': 2, 'course': 'French'},
]);
```