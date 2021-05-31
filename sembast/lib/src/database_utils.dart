import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/protected/database.dart';
import 'package:sembast/src/value_utils.dart';

/// Get the list of non empty store names.
Iterable<String> getNonEmptyStoreNames(Database database) =>
    (database as SembastDatabase).nonEmptyStoreNames;

/// Merge a database with an existing source database.
///
/// Existing records are removed.
///
/// if [storeNames] is not specified, it handles stores from both the source
/// and destination database.
Future<void> databaseMerge(Database db,
    {required Database sourceDatabase, List<String>? storeNames}) async {
  var names = storeNames ??
      List.from(Set.from(getNonEmptyStoreNames(db))
        ..addAll(Set.from(getNonEmptyStoreNames(sourceDatabase))));
  await db.transaction((transaction) async {
    for (var store in names) {
      await txnMergeStore(transaction,
          sourceDatabase: sourceDatabase, storeName: store);
    }
  });
}

/// Merge a given store in a transaction, assuming source database does not change
Future<void> txnMergeStore(Transaction txn,
    {required Database sourceDatabase, required String storeName}) async {
  var store = StoreRef(storeName);
  var originalRecords = await store.find(txn);
  var originalMap = <dynamic, RecordSnapshot>{
    for (var v in originalRecords) v.ref.key: v
  };

  var sourceRecords = await store.find(sourceDatabase);

  for (var record in sourceRecords) {
    /// Check and remove
    var original = originalMap.remove(record.ref.key);
    if (!valueAreEquals(original?.value, record.value)) {
      // Copy record
      await record.ref.put(txn, record.value);
    }
  }

  /// Delete remaining
  for (var remaining in originalMap.values) {
    await remaining.ref.delete(txn);
  }
}
