import 'dart:collection';

import 'package:sembast/src/finder_impl.dart';
import 'package:sembast/src/key_utils.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/sort.dart';
import 'package:sembast/src/transaction_impl.dart';
import 'package:sembast/src/utils.dart';

import 'common_import.dart';
import 'database_impl.dart';
import 'import_common.dart';

/// Store implementation.
class SembastStore {
  /// The database.
  final SembastDatabase database;

  /// Base store reference.
  final StoreRef<Key?, Value?> ref;

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
  SembastStore(this.database, String name) : ref = StoreRef<Key?, Value?>(name);

  /// The current transaction.
  SembastTransaction? get currentTransaction => database.currentTransaction;

  /// Execute in a transaction.
  Future<T> transaction<T>(
          FutureOr<T> Function(Transaction? transaction) action) =>
      database.transaction(action);

  /// put a record in a transaction.
  ///
  /// Return the value added
  Future<Object?> txnPut(SembastTransaction txn, Value value, Key key,
      {bool? merge, bool? ifNotExists}) async {
    try {
      return txnPutSync(txn, value, key,
          merge: merge, ifNotExists: ifNotExists);
    } finally {
      await database.txnPostWriteAndCooperate(txn);
    }
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

  /// Generate a new key (int or string only)
  Future<K> txnGenerateUniqueKey<K>(SembastTransaction txn) async {
    late K key;
    if (K == String) {
      key = await txnGenerateUniqueStringKey(txn) as K;
    } else if (K == int) {
      key = await txnGenerateUniqueIntKey(txn) as K;
    } else {
      // We might stop supporting that in the future...
      var intKey = await txnGenerateUniqueIntKey(txn);
      try {
        key = intKey as K;
      } catch (e) {
        throw ArgumentError(
            'Invalid key type $K for generating a key. You should either use String or int or generate the key yourself.');
      }
      // throw ArgumentError('Invalid key type $K for generating a key. You should either use String or int or generate the key yourself. Declare your store key as int or String explicitly such as `StoreRef<int, ...>` or `StoreRef<String, ...>`');
    }
    return key;
  }

  /// add a record in a transaction.
  ///
  /// Return the added key.
  Future<K?> txnAdd<K>(SembastTransaction txn, Value value, [Key? key]) async {
    // We allow generating a string key

    try {
      if (key == null) {
        key = await txnGenerateUniqueKey<K>(txn);
      } else if (await txnRecordExists(txn, key)) {
        return null;
      }
      txnPutSync(txn, value, key as Key);
      return key as K?;
    } finally {
      await database.txnPostWriteAndCooperate(txn);
    }
  }

  /// Returns the value
  Value? txnPutSync(SembastTransaction txn, Value value, Key key,
      {bool? merge, bool? ifNotExists}) {
    var hasChangesListener = this.hasChangesListener;
    RecordSnapshot? oldSnapshot;
    if (merge == true || ifNotExists == true || hasChangesListener) {
      oldSnapshot = txnGetRecordSync(txn, key);
    }
    if (ifNotExists == true) {
      if (merge == true) {
        throw ArgumentError('merge and ifNotExists cannot be both true');
      }
      if (oldSnapshot != null) {
        return oldSnapshot.value;
      }
    }
    ImmutableSembastRecord? record;
    if (merge == true) {
      // the value cannot be null
      value = mergeValue(oldSnapshot?.value, value, allowDotsInKeys: true);
      //}
    } else {
      // Simple clone the calue
      value = cloneValue(value);
    }
    record = ImmutableSembastRecord(ref.record(key), value);

    record = txnPutRecordSync(txn, record);
    if (database.logV) {
      // ignore: avoid_print
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
  Future<List> txnPutAll<PK, PV>(
      SembastTransaction txn, List<PV> values, List<PK> keys,
      {bool? merge}) async {
    try {
      final resultValues = <Object?>[];
      for (var i = 0; i < values.length; i++) {
        resultValues.add(
            txnPutSync(txn, values[i] as Value, keys[i] as Key, merge: merge));
        if (needCooperate) {
          await cooperate();
        }
      }
      return resultValues;
    } finally {
      if (database.txnPostWriteNeeded) {
        await database.txnPostWrite(txn);
      }
    }
  }

  /// Returns the list of keys
  Future<List<K?>> txnAddAll<K, V>(
      SembastTransaction txn, List<V> values, List<K> keys) async {
    final resultKeys = <K?>[];
    for (var i = 0; i < values.length; i++) {
      resultKeys.add(await txnAdd<K>(txn, values[i] as Value, keys[i] as Key));
    }
    return resultKeys;
  }

  /// Update a record in a transaction.
  ///
  /// Return the value updated
  Future<Object?> txnUpdate<K, V>(
      SembastTransaction txn, V value, K key) async {
    try {
      return txnUpdateSync(txn, value, key);
    } finally {
      await database.txnPostWriteAndCooperate(txn);
    }
  }

  /// Update a record in a transaction.
  ///
  /// Return the value updated
  Object? txnUpdateSync<K, V>(SembastTransaction txn, V value, K key) {
    var hasChangesListener = this.hasChangesListener;
    // Ignore non-existing record
    var existingRecord = txnGetRecordSync(txn, key);
    if (existingRecord == null) {
      return null;
    }

    var mergedValue = mergeValue(existingRecord.value, value);
    var record = ImmutableSembastRecord(ref.record(key as Key), mergedValue);

    var newSnapshot = txnPutRecordSync(txn, record);
    if (database.logV) {
      // ignore: avoid_print
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
      forEachRecords(transaction, Finder(filter: filter) as SembastFinder,
          (record) {
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
  Future<void> forEachRecords(SembastTransaction? txn, SembastFinder? finder,
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

  /// Cancel if false is returned
  ///
  /// Matchin filter and boundaries
  void forEachRecordsSync(SembastTransaction? txn, Finder? finder,
      bool Function(ImmutableSembastRecord record) action) {
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
        if (finderMatchesRecord(finder, record)) {
          if (action(record) == false) {
            return;
          }
        }
      }
    }

    var records = currentRecords;
    for (var record in records) {
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
  Future<Object?> txnFindKey(
          SembastTransaction? txn, SembastFinder? finder) async =>
      (await txnFindRecord(txn, finder))?.key;

  /// Find a record key in a transaction. synchronous version.
  Object? txnFindKeySync(SembastTransaction? txn, SembastFinder? finder) =>
      (txnFindRecordSync(txn, finder))?.key;

  /// Find a record in a transaction.
  Future<ImmutableSembastRecord?> txnFindRecord(
      SembastTransaction? txn, SembastFinder? finder) async {
    finder = cloneFinderFindFirst(finder);
    var records = await txnFindRecords(txn, finder);
    if (records.isNotEmpty) {
      return records.first;
    }
    return null;
  }

  /// Find a record in a transaction. Synchronous version
  ImmutableSembastRecord? txnFindRecordSync(
      SembastTransaction? txn, SembastFinder? finder) {
    finder = cloneFinderFindFirst(finder);
    var records = txnFindRecordsSync(txn, finder);
    if (records.isNotEmpty) {
      return records.first;
    }
    return null;
  }

  /// Find records in a transaction.
  Future<List<ImmutableSembastRecord>> txnFindRecords(
      SembastTransaction? txn, SembastFinder? finder) async {
    if (!cooperateOn) {
      return txnFindRecordsSync(txn, finder);
    }
    var finderData = _FinderData(finder);

    await forEachRecords(txn, finder, finderData.addRecord);
    var results = finderData.addedResults;

    if (finder != null) {
      if (finderData.hasSortOrder) {
        var sort = Sort(database.cooperator!);
        await sort.sort(
            results,
            (SembastRecord record1, SembastRecord record2) =>
                finder.compareThenKey(record1, record2));

        // Apply limits
        results = recordsLimit(results, finder)!;
      }
    } else {
      // Already sorted by SplayTreeMap and offset and limit handled
    }
    return results;
  }

  /// Find records in a transaction. synchronous access.
  List<ImmutableSembastRecord> txnFindRecordsSync(
      SembastTransaction? txn, SembastFinder? finder) {
    var finderData = _FinderData(finder);

    forEachRecordsSync(txn, finder, finderData.addRecord);
    var results = finderData.addedResults;

    if (finder != null) {
      // sort
      if (finderData.hasSortOrder) {
        results.sort(
            (record1, record2) => finder.compareThenKey(record1, record2));

        // Apply limits
        results = recordsLimit(results, finder)!;
      }
    } else {
      // Already sorted by SplayTreeMap and offset and limit handled
    }
    return results;
  }

  /// Find keys in a transaction.
  Future<List<Object?>> txnFindKeys(
      SembastTransaction? txn, SembastFinder? finder) async {
    var records = await txnFindRecords(txn, finder);
    return records.map((SembastRecord record) => record.key).toList();
  }

  /// Find keys in a transaction. synchronous access.
  List<Object?> txnFindKeysSync(
      SembastTransaction? txn, SembastFinder? finder) {
    var records = txnFindRecordsSync(txn, finder);
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
      recordMap[record.key] = record;
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
    if (needCooperate) {
      await cooperate();
    }
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

    // update last int key in case auto gen is needed again
    var recordKey = sembastRecord.key;
    if (recordKey is int) {
      final intKey = recordKey;
      if (intKey > lastIntKey) {
        lastIntKey = intKey;
      }
    }

    // add to store transaction
    checkTransaction(txn);
    txnRecords ??= <Object, TxnRecord>{};

    txnRecords![sembastRecord.key] = TxnRecord(sembastRecord);

    // Remove the store from the dropped store list if needed
    database.txnUndeleteStore(txn, sembastRecord.ref.store.name);

    return sembastRecord;
  }

  ///
  /// Return the current immutable value
  ///
  /// null if not present. could be a deleted item
  ImmutableSembastRecord? txnGetImmutableRecordSync<K>(
      SembastTransaction? txn, K key) {
    ImmutableSembastRecord? record;

    // look in current transaction
    checkTransaction(txn);
    if (_hasTransactionRecords(txn)) {
      record = txnRecords![key]?.record;
    }

    record ??= recordMap[key];

    if (database.logV) {
      // ignore: avoid_print
      print('${database.currentTransaction} get $record key $key');
    }
    return record;
  }

  /// Get a record in a transaction.
  Future<ImmutableSembastRecord?> txnGetRecord(
      SembastTransaction? txn, Key key) async {
    var record = txnGetRecordSync(txn, key);
    // Cooperate after!
    if (needCooperate) {
      await cooperate();
    }
    return record;
  }

  /// Get a casted record by key in a transaction.
  Future<RecordSnapshot<K, V>?>
      txnGetRecordSnapshot<K extends Key?, V extends Value?>(
          SembastTransaction? txn, K key) async {
    return (await txnGetRecord(txn, key as Key))?.cast<K, V>();
  }

  /// Check if a record exists in a transaction.
  Future<bool> txnRecordExists(SembastTransaction? txn, Object key) async {
    var exists = txnRecordExistsSync(txn, key);
    // Cooperate after!
    if (needCooperate) {
      await cooperate();
    }
    return exists;
  }

  /// Check if a record exists in a transaction synchronously.
  bool txnRecordExistsSync(SembastTransaction? txn, Object key) {
    var record = txnGetImmutableRecordSync(txn, key);
    return (record?.deleted == false);
  }

  /// Get a record by key in a transaction.
  ImmutableSembastRecord? txnGetRecordSync<K>(SembastTransaction? txn, K key) {
    var record = txnGetImmutableRecordSync(txn, key);
    if (record == null || record.deleted) {
      return null;
    }
    return record;
  }

  /// Get a casted record by key in a transaction.
  RecordSnapshot<K, V>? txnGetRecordSnapshotSync<K, V>(
      SembastTransaction? txn, K key) {
    return txnGetRecordSync(txn, key)?.cast<K, V>();
  }

  /// Return records ignoring non found ones and deleted
  Future<List<ImmutableSembastRecord?>> txnGetRecordsCompat(
      SembastTransaction? txn, Iterable keys) async {
    final records = <ImmutableSembastRecord?>[];

    for (var key in keys) {
      var record = txnGetImmutableRecordSync(txn, key as Object);
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
      snapshots.add(txnGetRecordSnapshotSync(txn, key));
      if (needCooperate) {
        await cooperate();
      }
    }
    return snapshots;
  }

  /// Return records, not found and delete as null
  List<RecordSnapshot<K, V>?> txnGetRecordSnapshotsSync<K, V>(
      SembastTransaction? txn, RecordsRef<K, V> refs) {
    return refs.keys
        .map((key) => txnGetRecordSnapshotSync<K, V>(txn, key))
        .toList();
  }

  /// Count records in a transaction without filter.
  int txnNoFilterTransactionRecordCount(SembastTransaction? txn) {
    // Use the current record list
    var count = recordMap.length;

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
    return count;
  }

  /// Count records in a transaction.
  Future<int> txnCount(SembastTransaction? txn, Filter? filter) async {
    var count = 0;
    // no filter optimization
    if (filter == null) {
      // Use the current record list
      count += txnNoFilterTransactionRecordCount(txn);
    } else {
      // There is a filter, count manually
      await forEachRecords(txn, Finder(filter: filter) as SembastFinder,
          (record) {
        count++;
        return true;
      });
    }
    return count;
  }

  /// Count records in a transaction. Synchronous version.
  int txnCountSync(SembastTransaction? txn, Filter? filter) {
    var count = 0;
    // no filter optimization
    if (filter == null) {
      // Use the current record list
      count += txnNoFilterTransactionRecordCount(txn);
    } else {
      // There is a filter, count manually
      forEachRecordsSync(txn, Finder(filter: filter) as SembastFinder,
          (record) {
        count++;
        return true;
      });
    }
    return count;
  }

  /// Count records in a transaction.
  Future<Set> txnFilterKeys(SembastTransaction? txn, Filter? filter) async {
    Set keys;
    // no filter optimization
    if (filter == null) {
      // Use the current record list
      keys = recordMap.keys.toSet();

      // Apply any transaction change
      if (_hasTransactionRecords(txn)) {
        txnRecords!.forEach((key, value) {
          var deleted = value.deleted;
          if (deleted) {
            keys.remove(key);
          } else {
            keys.add(key);
          }
        });
      }
    } else {
      keys = {};
      // There is a filter, count manually
      await forEachRecords(txn, Finder(filter: filter) as SembastFinder,
          (record) {
        keys.add(record.key);
        return true;
      });
    }
    return keys;
  }

  /// Delete a record in a transaction.
  Future<Object?> txnDelete(SembastTransaction txn, Object key) async {
    try {
      return txnDeleteSync(txn, key);
    } finally {
      await database.txnPostWriteAndCooperate(txn);
    }
  }

  /// Delete and register changes.
  Object? txnDeleteSync(SembastTransaction txn, Object key) {
    var record = txnGetImmutableRecordSync(txn, key);
    if (record == null) {
      return null;
    } else {
      // Do the deletion
      // clone and mark as deleted
      var clone = record.sembastCloneAsDeleted();
      txnPutRecordSync(txn, clone);

      // Changes listener
      if (hasChangesListener) {
        database.changesListener.addChange(record, null);
      }
      return record.key;
    }
  }

  /// Delete multiple records in a transaction.
  Future<List> txnDeleteAll(
      SembastTransaction txn, Iterable<Object?> keys) async {
    final deletedKeys = <Object?>[];
    try {
      final updates = <ImmutableSembastRecord>[];
      // make it safe in a async way
      keys = List<Object?>.from(keys, growable: false);
      for (var key in keys) {
        await cooperate();
        var record = txnGetImmutableRecordSync(txn, key as Object);
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
    } finally {
      await database.txnPostWriteAndCooperate(txn);
    }
    return deletedKeys;
  }

  /// Update records in a transaction.
  Future<List> txnUpdateAll<K, V>(
      SembastTransaction txn, List<V> values, List<K> keys) async {
    final resultValues = <Object?>[];
    try {
      for (var i = 0; i < values.length; i++) {
        resultValues.add(txnUpdateSync(txn, values[i] as Value, keys[i]));
        if (needCooperate) {
          await cooperate();
        }
      }
    } finally {
      await database.txnPostWrite(txn);
    }
    return resultValues;
  }

  bool _hasTransactionRecords(SembastTransaction? txn) {
    return txn != null && txn == currentTransaction && txnRecords != null;
  }

  /// Check if a key exists in a transaction.
  bool txnContainsKey(SembastTransaction? txn, Key key) {
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
  Future<List<Object?>> txnClear(SembastTransaction txn,
      {SembastFinder? finder}) async {
    if (finder == null) {
      var deletedKeys = <Object?>[];
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
  Future<List> txnUpdateWhere(SembastTransaction txn, Value value,
      {SembastFinder? finder}) async {
    var keys = await txnFindKeys(txn, finder);
    try {
      for (var key in keys) {
        txnPutSync(txn, value, key as Object, merge: true);
        if (needCooperate) {
          await cooperate();
        }
      }
    } finally {
      if (database.txnPostWriteNeeded) {
        await database.txnPostWrite(txn);
      }
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

/// Find data helper shared between asynchronous and asynchronous read access.
class _FinderData {
  // Two ways of storing data
  late List<ImmutableSembastRecord> results;
  late SplayTreeMap<Object?, ImmutableSembastRecord> preOrderedResults;

  // Use pre-ordered or not
  // Pre-ordered means we have no sort and don't need to go though all
  // the records.
  final SembastFinder? sembastFinder;

  late var hasSortOrder = sembastFinder?.sortOrders?.isNotEmpty ?? false;
  late var usePreordered = !hasSortOrder;
  var preorderedCurrentOffset = 0;

  _FinderData(this.sembastFinder) {
    if (usePreordered) {
      // Preordered by key
      preOrderedResults =
          SplayTreeMap<Object?, ImmutableSembastRecord>(compareKey);
    } else {
      results = <ImmutableSembastRecord>[];
    }
  }

  /// get the results added
  List<ImmutableSembastRecord> get addedResults {
    if (usePreordered) {
      return preOrderedResults.values.toList(growable: false);
    } else {
      return results;
    }
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
      results.add(record);
    }
    return true;
  }
}
