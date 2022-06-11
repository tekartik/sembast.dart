import 'dart:collection';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/finder_impl.dart';
import 'package:sembast/src/key_utils.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/record_snapshot_impl.dart';
import 'package:sembast/src/sort.dart';
import 'package:sembast/src/transaction_impl.dart';
import 'package:sembast/src/utils.dart';

import 'common_import.dart';
import 'database_impl.dart';

/// Store implementation.
class SembastStore {
  /// The database.
  final SembastDatabase database;

  /// Store reference.
  final StoreRef<Object?, Object?> ref;

  ///
  /// Store name
  ///
  String get name => ref.name;

  /// for key generation
  int lastIntKey = 0;

  /// Record map.
  ///
  /// Use a splay tree to be correctly ordered. To access in a synchronous way.
  Map<Object, ImmutableSembastRecord> recordMap =
      SplayTreeMap<Object, ImmutableSembastRecord>(compareKey);

  /// Records change during the transaction.
  Map<Object, TxnRecord>? txnRecords;

  /// Check a transaction. (can be null)
  void checkTransaction(SembastTransaction? transaction) =>
      database.checkTransaction(transaction);

  // bool get isInTransaction => database.isInTransaction;
  /// Store implementation.
  SembastStore(this.database, String name)
      : ref = StoreRef<Object?, Object?>(name);

  /// The current transaction.
  SembastTransaction? get currentTransaction => database.currentTransaction;

  /// Execute in a transaction.
  Future<T> transaction<T>(
          FutureOr<T> Function(Transaction? transaction) action) =>
      database.transaction(action);

  /// put a record in a transaction.
  ///
  /// Return the value added
  Future<Object?> txnPut(SembastTransaction txn, var value, var key,
      {bool? merge}) async {
    await cooperate();
    return txnPutSync(txn, value, key, merge: merge);
  }

  /// Generate a new int key
  Future<int> txnGenerateUniqueIntKey(SembastTransaction? txn) async {
    int? key;
    do {
      // Use a generator if any, but only once per store
      key = await database.generateUniqueIntKey(name);
      key ??= ++lastIntKey;
    } while (await txnRecordExists(txn, key));
    return key;
  }

  /// Generate a new String key
  Future<String> txnGenerateUniqueStringKey(SembastTransaction? txn) async {
    String? key;
    do {
      // Use a generator if any
      key = await database.generateUniqueStringKey(name);
      key ??= generateStringKey();
    } while (await txnRecordExists(txn, key));
    return key;
  }

  /// add a record in a transaction.
  ///
  /// Return the added key.
  Future<K?> txnAdd<K, V>(SembastTransaction txn, var value, [K? key]) async {
    await cooperate();
    // We allow generating a string key

    if (key == null) {
      // We make sure the key is unique

      if (K == String) {
        key = await txnGenerateUniqueStringKey(txn) as K;
      } else {
        var intKey = await txnGenerateUniqueIntKey(txn);
        try {
          key = intKey as K;
        } catch (e) {
          throw ArgumentError(
              'Invalid key type $K for generating a key. You should either use String or int or generate the key yourself.');
        }
      }
    } else if (await txnRecordExists(txn, key)) {
      return null;
    }

    await txnPutSync(txn, value, key);
    return key;
  }

  /// Returns the value
  Future<Object?> txnPutSync(SembastTransaction txn, var value, var key,
      {bool? merge}) async {
    RecordSnapshot? oldSnapshot;
    var hasChangesListener = this.hasChangesListener;
    ImmutableSembastRecord? record;
    if (merge == true) {
      record = txnGetRecordSync(txn, key);

      oldSnapshot = record;

      //if (record != null) {
      // Always merge to get rid of FieldValue.delete if any
      value = mergeValue(record?.value, value, allowDotsInKeys: true);
      //}
    } else {
      if (hasChangesListener) {
        oldSnapshot = txnGetRecordSync(txn, key);
      }
      // Simple clone the calue
      value = cloneValue(value);
    }
    record = ImmutableSembastRecord(ref.record(key), value);

    record = txnPutRecordSync(txn, record);
    if (database.logV) {
      print('$txn put $record');
    }

    /// track changes
    if (hasChangesListener) {
      database.changesListener.addChange(oldSnapshot, record);
    }
    return record.value;
  }

  /// True if it has a change listener
  bool get hasChangesListener =>
      database.changesListener.hasStoreChangeListener(ref);

  /// Returns the list of values
  Future<List> txnPutAll(SembastTransaction txn, List values, List keys,
      {bool? merge}) async {
    final resultValues = [];
    for (var i = 0; i < values.length; i++) {
      resultValues.add(await txnPut(txn, values[i], keys[i], merge: merge));
    }
    return resultValues;
  }

  /// Returns the list of keys
  Future<List<K?>> txnAddAll<K, V>(
      SembastTransaction txn, List<V> values, List<K> keys) async {
    final resultKeys = <K?>[];
    for (var i = 0; i < values.length; i++) {
      resultKeys.add(await txnAdd<K, V>(txn, values[i], keys[i]));
    }
    return resultKeys;
  }

  /// Update a record in a transaction.
  ///
  /// Return the value updated
  Future<Object?> txnUpdate(
      SembastTransaction txn, dynamic value, dynamic key) async {
    await cooperate();

    var hasChangesListener = this.hasChangesListener;
    // Ignore non-existing record
    var existingRecord = txnGetRecordSync(txn, key);
    if (existingRecord == null) {
      return null;
    }

    var mergedValue = mergeValue(existingRecord.value, value);
    var record = ImmutableSembastRecord(ref.record(key), mergedValue);

    var newSnapshot = txnPutRecordSync(txn, record);
    if (database.logV) {
      print('$txn update $record');
    }
    if (hasChangesListener) {
      database.changesListener.addChange(existingRecord, newSnapshot);
    }
    return record.value;
  }

  ///
  /// stream all the records TODO
  ///
  Stream<RecordSnapshot<K, V>> txnGetStream<K, V>(
      SembastTransaction? transaction, Filter? filter) {
    late StreamController<RecordSnapshot<K, V>> ctlr;
    ctlr = StreamController<RecordSnapshot<K, V>>(onListen: () {
      forEachRecords(transaction, Finder(filter: filter), (record) {
        if (ctlr.isClosed) {
          return false;
        }
        ctlr.add(record.cast<K, V>());
        return true;
      }).whenComplete(() {
        ctlr.close();
      });
    });

    return ctlr.stream;
  }

  /// Get the list of current records that can be safely iterate even
  /// in an async way.
  List<ImmutableSembastRecord> get currentRecords =>
      recordMap.values.toList(growable: false);

  /// Use only once for loop in a safe way in a transaction record list
  ///
  /// can be null
  List<ImmutableSembastRecord>? get txnCurrentRecords => txnRecords?.values
      .map((txnRecord) => txnRecord.record)
      .toList(growable: false);

  /// Can be null
  List<TxnRecord>? get currentTxnRecords => txnRecords == null
      ? null
      : List<TxnRecord>.from(txnRecords!.values, growable: false);

  /// Cancel if false is returned
  ///
  /// Matchin filter and boundaries
  Future forEachRecords(SembastTransaction? txn, Finder? finder,
      bool Function(ImmutableSembastRecord record) action) async {
    bool finderMatchesRecord(Finder? finder, ImmutableSembastRecord record) {
      if (record.deleted) {
        return false;
      }
      var sembastFinder = finder as SembastFinder?;
      return finderMatchesFilterAndBoundaries(sembastFinder, record);
    }

    // handle record in transaction first
    if (_hasTransactionRecords(txn)) {
      // Copy for cooperate
      var records = txnCurrentRecords!;
      for (var record in records) {
        if (needCooperate) {
          await cooperate();
        }

        if (finderMatchesRecord(finder, record)) {
          if (action(record) == false) {
            return;
          }
        }
      }
    }

    var records = currentRecords;
    for (var record in records) {
      // then the regular unless already in transaction
      if (needCooperate) {
        await cooperate();
      }

      if (_hasTransactionRecords(txn)) {
        if (txnRecords!.keys.contains(record.key)) {
          // already handled
          continue;
        }
      }
      if (finderMatchesRecord(finder, record)) {
        if (action(record) == false) {
          return;
        }
      }
    }
  }

  /// Find a record key in a transaction.
  Future txnFindKey(SembastTransaction? txn, Finder? finder) async =>
      (await txnFindRecord(txn, finder))?.key;

  /// Find a record in a transaction.
  Future<ImmutableSembastRecord?> txnFindRecord(
      SembastTransaction? txn, Finder? finder) async {
    finder = cloneFinderFindFirst(finder);
    var records = await txnFindRecords(txn, finder);
    if (records.isNotEmpty) {
      return records.first;
    }
    return null;
  }

  /// Find records in a transaction.
  Future<List<ImmutableSembastRecord>> txnFindRecords(
      SembastTransaction? txn, Finder? finder) async {
    // Two ways of storing data
    List<ImmutableSembastRecord>? results;
    late SplayTreeMap<Object?, ImmutableSembastRecord> preOrderedResults;

    // Use pre-ordered or not
    // Pre-ordered means we have no sort and don't need to go though all
    // the records.
    var sembastFinder = finder as SembastFinder?;
    var hasSortOrder = sembastFinder?.sortOrders?.isNotEmpty ?? false;
    var usePreordered = !hasSortOrder;
    var preorderedCurrentOffset = 0;
    if (usePreordered) {
      // Preordered by key
      preOrderedResults =
          SplayTreeMap<Object?, ImmutableSembastRecord>(compareKey);
    } else {
      results = <ImmutableSembastRecord>[];
    }

    bool addRecord(ImmutableSembastRecord record) {
      if (usePreordered) {
        // We can handle offset and limit directly too
        if (sembastFinder?.offset != null) {
          if (preorderedCurrentOffset++ < sembastFinder!.offset!) {
            // Next!
            return true;
          }
        }
        if (sembastFinder?.limit != null) {
          if (preOrderedResults.length >= sembastFinder!.limit! - 1) {
            // Add an stop
            preOrderedResults[record.key] = record;
            return false;
          }
        }
        preOrderedResults[record.key] = record;
      } else {
        results!.add(record);
      }
      return true;
    }

    await forEachRecords(txn, sembastFinder, addRecord);
    if (usePreordered) {
      results = preOrderedResults.values.toList(growable: false);
    }

    if (finder != null) {
      // sort
      if (hasSortOrder) {
        if (cooperateOn) {
          var sort = Sort(database.cooperator!);
          await sort.sort(
              results!,
              (SembastRecord record1, SembastRecord record2) =>
                  sembastFinder!.compareThenKey(record1, record2));
        } else {
          results!.sort((record1, record2) =>
              sembastFinder!.compareThenKey(record1, record2));
        }

        // Apply limits
        results = recordsLimit(results, sembastFinder);
      }
    } else {
      // Already sorted by SplayTreeMap and offset and limit handled
    }
    return results!;
  }

  /// Find keys in a transaction.
  Future<List> txnFindKeys(SembastTransaction? txn, Finder? finder) async {
    var records = await txnFindRecords(txn, finder);
    return records.map((SembastRecord record) => record.key).toList();
  }

  ///
  /// return true if it existed before
  ///
  bool setRecordInMemory(ImmutableSembastRecord record) {
    //SembastStore store = record.store as SembastStore;
    final exists = recordMap[record.key] != null;
    if (record.deleted) {
      recordMap.remove(record.key);
    } else {
      recordMap[record.key as Object] = record;
    }
    return exists;
  }

  /// Load a record.
  void loadRecord(ImmutableSembastRecord record) {
    var key = record.key;
    setRecordInMemory(record);
    // update for auto increment
    if (key is int) {
      if (key > lastIntKey) {
        lastIntKey = key;
      }
    }
  }

  /// Put a record in a transaction.
  Future<ImmutableSembastRecord> txnPutRecord(
      SembastTransaction txn, ImmutableSembastRecord record) async {
    await cooperate();
    return txnPutRecordSync(txn, record);
  }

  /// Put a record in a transaction.
  ImmutableSembastRecord txnPutRecordSync(
      SembastTransaction txn, ImmutableSembastRecord record) {
    ImmutableSembastRecord sembastRecord;
    if (database.storageJdb != null) {
      sembastRecord = makeImmutableRecordJdb(record);
    } else {
      sembastRecord = record;
    }

    // auto-gen key if needed
    if (sembastRecord.key == null) {
      // Compat only
      // throw StateError('key should not be null');
      sembastRecord.ref = ref.record(++lastIntKey);
    } else {
      // update last int key in case auto gen is needed again
      var recordKey = sembastRecord.key;
      if (recordKey is int) {
        final intKey = recordKey;
        if (intKey > lastIntKey) {
          lastIntKey = intKey;
        }
      }
    }
    // add to store transaction
    checkTransaction(txn);
    txnRecords ??= <Object, TxnRecord>{};

    txnRecords![sembastRecord.key as Object] = TxnRecord(sembastRecord);

    // Remove the store from the dropped store list if needed
    database.txnUndeleteStore(txn, sembastRecord.ref.store.name);

    return sembastRecord;
  }

  ///
  /// Return the current immutable value
  ///
  /// null if not present. could be a deleted item
  ImmutableSembastRecord? txnGetImmutableRecordSync(
      SembastTransaction? txn, var key) {
    ImmutableSembastRecord? record;

    // look in current transaction
    checkTransaction(txn);
    if (_hasTransactionRecords(txn)) {
      record = txnRecords![key]?.record;
    }

    record ??= recordMap[key];

    if (database.logV) {
      print('${database.currentTransaction} get $record key $key');
    }
    return record;
  }

  /// Get a record in a transaction.
  Future<ImmutableSembastRecord?> txnGetRecord(
      SembastTransaction? txn, key) async {
    var record = txnGetRecordSync(txn, key);
    // Cooperate after!
    if (needCooperate) {
      await cooperate();
    }
    return record;
  }

  /// Check if a record exists in a transaction.
  Future<bool> txnRecordExists(SembastTransaction? txn, key) async {
    var record = txnGetImmutableRecordSync(txn, key);
    // Cooperate after!
    if (needCooperate) {
      await cooperate();
    }
    return (record?.deleted == false);
  }

  /// Get a record by key in a transaction.
  ImmutableSembastRecord? txnGetRecordSync(SembastTransaction? txn, key) {
    var record = txnGetImmutableRecordSync(txn, key);
    if (record == null || record.deleted) {
      return null;
    }
    return record;
  }

  /// Return records ignoring non found ones and deleted
  Future<List<ImmutableSembastRecord?>> txnGetRecordsCompat(
      SembastTransaction? txn, Iterable keys) async {
    final records = <ImmutableSembastRecord?>[];

    for (var key in keys) {
      var record = txnGetImmutableRecordSync(txn, key);
      if (record != null) {
        if (!record.deleted) {
          records.add(record);
        } else {
          records.add(null);
        }
      } else {
        records.add(null);
      }
      if (needCooperate) {
        await cooperate();
      }
    }
    return records;
  }

  /// Return records, not found and delete as null
  Future<List<RecordSnapshot<K, V>?>> txnGetRecordSnapshots<K, V>(
      SembastTransaction? txn, RecordsRef<K, V> refs) async {
    final snapshots = <RecordSnapshot<K, V>?>[];

    for (var key in refs.keys) {
      var immutable = txnGetImmutableRecordSync(txn, key);
      if (immutable != null && (!immutable.deleted)) {
        snapshots.add(SembastRecordSnapshot<K, V>.fromRecord(immutable));
      } else {
        snapshots.add(null);
      }
      if (needCooperate) {
        await cooperate();
      }
    }
    return snapshots;
  }

  /// Count records in a transaction.
  Future<int> txnCount(SembastTransaction? txn, Filter? filter) async {
    var count = 0;
    // no filter optimization
    if (filter == null) {
      // Use the current record list
      count += recordMap.length;

      // Apply any transaction change
      if (_hasTransactionRecords(txn)) {
        txnRecords!.forEach((key, value) {
          var deleted = value.deleted;
          if (recordMap.containsKey(key)) {
            if (deleted) {
              count--;
            }
          } else {
            if (!deleted) {
              count++;
            }
          }
        });
      }
    } else {
      // There is a filter, count manually
      await forEachRecords(txn, Finder(filter: filter), (record) {
        count++;
        return true;
      });
    }
    return count;
  }

  /// Delete a record in a transaction.
  Future<Object?> txnDelete(SembastTransaction txn, var key) async {
    var record = txnGetImmutableRecordSync(txn, key);
    await cooperate();
    if (record == null) {
      return null;
    } else {
      // Do the deletion
      // clone and mark as deleted
      var clone = record.sembastCloneAsDeleted();
      await txnPutRecord(txn, clone);

      // Changes listener
      if (hasChangesListener) {
        database.changesListener.addChange(record, null);
      }
      return record.key;
    }
  }

  /// Delete multiple records in a transaction.
  Future<List> txnDeleteAll(SembastTransaction txn, Iterable keys) async {
    final updates = <ImmutableSembastRecord>[];
    final deletedKeys = [];

    // make it safe in a async way
    keys = List.from(keys, growable: false);
    for (var key in keys) {
      await cooperate();
      var record = txnGetImmutableRecordSync(txn, key);
      if (record != null && !record.deleted) {
        // Clone and mark deleted
        var clone = record.sembastCloneAsDeleted();

        updates.add(clone);

        if (txn.database.changesListener.isNotEmpty) {
          txn.database.changesListener.addChange(record, null);
        }
        deletedKeys.add(key);
      } else {
        deletedKeys.add(null);
      }
    }

    if (updates.isNotEmpty) {
      await database.txnPutRecords(txn, updates);
    }
    return deletedKeys;
  }

  /// Update records in a transaction.
  Future<List> txnUpdateAll(
      SembastTransaction txn, List values, List keys) async {
    final resultValues = [];
    for (var i = 0; i < values.length; i++) {
      resultValues.add(await txnUpdate(txn, values[i], keys[i]));
    }
    return resultValues;
  }

  bool _hasTransactionRecords(SembastTransaction? txn) {
    return txn != null && txn == currentTransaction && txnRecords != null;
  }

  /// Check if a key exists in a transaction.
  bool txnContainsKey(SembastTransaction? txn, key) {
    if (recordMap.containsKey(key)) {
      return true;
    } else if (_hasTransactionRecords(txn)) {
      return txnRecords!.containsKey(key);
    } else {
      return false;
    }
  }

  /// Cancel changes.
  void rollback() {
    // clear map;
    txnRecords = null;
  }

  ///
  /// debug json
  ///
  Map<String, Object?> toJson() {
    var map = <String, Object?>{};
    map['name'] = name;

    map['count'] = recordMap.length;

    return map;
  }

  @override
  String toString() {
    return name;
  }

  /// Clear a store in a transaction.
  Future<List> txnClear(SembastTransaction txn, {Finder? finder}) async {
    if (finder == null) {
      var deletedKeys = [];
      if (_hasTransactionRecords(txn)) {
        deletedKeys.addAll(await txnDeleteAll(
            txn, List.from(txnRecords!.keys, growable: false)));
      }
      final keys = recordMap.keys;
      deletedKeys
          .addAll(await txnDeleteAll(txn, List.from(keys, growable: false)));
      return deletedKeys;
    } else {
      var keys = await txnFindKeys(txn, finder);
      return await txnDeleteAll(txn, List.from(keys, growable: false));
    }
  }

  /// Update records in a transaction.
  Future<List> txnUpdateWhere(SembastTransaction txn, dynamic value,
      {Finder? finder}) async {
    var keys = await txnFindKeys(txn, finder);
    for (var key in keys) {
      await txnPut(txn, value, key, merge: true);
    }
    return keys;
  }

  //
// Cooperate mode
//
  /// true if it needs cooperation.
  bool get needCooperate => database.needCooperate;

  /// true if cooperation is activated.
  bool get cooperateOn => database.cooperateOn;

  /// Cooperate if needed.
  FutureOr cooperate() => database.cooperate();
}

/// Filter start boundary, assume ordered result
bool finderRecordMatchBoundaries(SembastFinder finder, RecordSnapshot result) {
  if (finder.start != null) {
    if (!finder.starts(result, finder.start)) {
      return false;
    }
  }
  if (finder.end != null) {
    if (!finder.ends(result, finder.end)) {
      return false;
    }
  }
  return true;
}
