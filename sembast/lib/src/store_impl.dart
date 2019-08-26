import 'dart:math';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/compat/finder.dart';
import 'package:sembast/src/filter_impl.dart';
import 'package:sembast/src/key_utils.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/record_impl.dart' as record_impl;
import 'package:sembast/src/record_snapshot_impl.dart';
import 'package:sembast/src/sort.dart';
import 'package:sembast/src/transaction_impl.dart';
import 'package:sembast/src/utils.dart';

import 'common_import.dart';
import 'database_impl.dart';

// ignore_for_file: deprecated_member_use_from_same_package

class SembastStore implements Store {
  final SembastDatabase database;
  @override
  final StoreRef<dynamic, dynamic> ref;

  @override
  Store get store => this;

  ///
  /// Store name
  ///
  @override
  String get name => ref.name;

  // for key generation
  int lastIntKey = 0;

  Map<dynamic, ImmutableSembastRecord> recordMap =
      <dynamic, ImmutableSembastRecord>{};
  Map<dynamic, TxnRecord> txnRecords;

  void checkTransaction(SembastTransaction transaction) =>
      database.checkTransaction(transaction);

  // bool get isInTransaction => database.isInTransaction;

  SembastStore(this.database, String name)
      : ref = StoreRef<dynamic, dynamic>(name);

  SembastTransaction get currentTransaction => database.currentTransaction;

  // SembastTransaction get zoneTransaction => database.zoneTransaction;

  Future<T> transaction<T>(FutureOr<T> action(Transaction transaction)) =>
      database.transaction(action);

  // return the key
  @override
  Future put(var value, [var key]) {
    return transaction((txn) async {
      if (key == null) {
        return txnAdd(txn as SembastTransaction, value);
      } else {
        await txnPut(txn as SembastTransaction, value, key);
        return key;
      }
    });
  }

  @override
  Future update(dynamic value, dynamic key) {
    return transaction((txn) async {
      return cloneValue(await txnUpdate(txn as SembastTransaction, value, key));
    });
  }

  Future<dynamic> txnPut(SembastTransaction txn, var value, var key,
      {bool merge}) async {
    await cooperate();
    return txnPutSync(txn, value, key, merge: merge);
  }

  Future<K> txnAdd<K, V>(SembastTransaction txn, var value, [K key]) async {
    await cooperate();
    // We allow generating a string key

    if (key == null) {
      // We make sure the key is unique
      do {
        if (K == String) {
          key = generateStringKey() as K;
        } else {
          try {
            key = ++lastIntKey as K;
          } catch (e) {
            throw ArgumentError(
                'Invalid key type $K for generating a key. You should either use String or int or generate the key yourself');
          }
        }
      } while (await txnRecordExists(txn, key));
    } else if (await txnRecordExists(txn, key)) {
      return null;
    }

    await txnPutSync(txn, value, key);
    return key;
  }

  /// Returns the value
  Future<dynamic> txnPutSync(SembastTransaction txn, var value, var key,
      {bool merge}) async {
    Record record;
    if (merge == true) {
      record = txnGetRecordSync(txn, key);
      if (record != null) {
        value = mergeValue(record.value, value, allowDotsInKeys: true);
      }
    }
    record = SembastRecord(this, value, key);

    record = txnPutRecordSync(txn, record);
    if (database.logV) {
      SembastDatabase.logger.fine("${txn} put ${record}");
    }
    return record.value;
  }

  /// Returns the list of values
  Future<List> txnPutAll(SembastTransaction txn, List values, List keys,
      {bool merge}) async {
    List resultKeys = [];
    for (int i = 0; i < values.length; i++) {
      resultKeys.add(await txnPut(txn, values[i], keys[i], merge: merge));
    }
    return resultKeys;
  }

  Future<dynamic> txnUpdate(
      SembastTransaction txn, dynamic value, dynamic key) async {
    await cooperate();
    // Ignore non-existing record
    var existingRecord = txnGetRecordSync(txn, key);
    if (existingRecord == null) {
      return null;
    }

    var mergedValue = mergeValue(existingRecord.value, value);
    Record record = SembastRecord(this, mergedValue, key);

    txnPutRecordSync(txn, record);
    if (database.logV) {
      SembastDatabase.logger.fine("${txn} update ${record}");
    }
    return record.value;
  }

  ///
  /// stream all the records
  ///
  @override
  Stream<Record> get records {
    StreamController<Record> ctlr = StreamController();
    // asynchronous feeding
    _feedController(null, ctlr).then((_) {
      ctlr.close();
    });
    return ctlr.stream;
  }

  Future _feedController(
      SembastTransaction txn, StreamController<Record> ctlr) async {
    await forEachRecords(txn, null, (record) {
      ctlr.add(makeOutRecord(record));
      return true;
    });
  }

  ///
  /// stream all the records
  ///
  Stream<Record> txnGetRecordsStream(SembastTransaction transaction) {
    StreamController<Record> ctlr = StreamController();
    _feedController(transaction, ctlr).then((_) {
      ctlr.close();
    });
    return ctlr.stream;
  }

  ///
  /// stream all the records TODO
  ///
  Stream<RecordSnapshot<K, V>> txnGetStream<K, V>(
      SembastTransaction transaction, Filter filter) {
    var ctlr = StreamController<RecordSnapshot<K, V>>();

    forEachRecords(transaction, filter, (record) {
      if (ctlr.isClosed) {
        return false;
      }
      ctlr.add(record.cast<K, V>());
      return true;
    }).whenComplete(() {
      ctlr.close();
    });
    return ctlr.stream;
  }

  /// Get the list of current records that can be safely iterate even
  /// in an async way.
  List<ImmutableSembastRecord> get currentRecords =>
      recordMap.values?.toList(growable: false);

  /// Use only once for loop in a safe way in a transaction record list
  ///
  /// can be null
  List<ImmutableSembastRecord> get txnCurrentRecords => txnRecords?.values
      ?.map((txnRecord) => txnRecord.record)
      ?.toList(growable: false);

  /// Can be null
  List<TxnRecord> get currentTxnRecords => txnRecords == null
      ? null
      : List<TxnRecord>.from(txnRecords.values, growable: false);

  /// Cancel if false is returned
  Future forEachRecords(SembastTransaction txn, Filter filter,
      bool action(ImmutableSembastRecord record)) async {
    bool _filterMatchRecord(Filter filter, Record record) {
      if (filter is SembastFilterBase) {
        if (record.deleted) {
          return false;
        }
        return filterMatchesRecord(filter, record);
      } else {
        // compat
        return Filter.matchRecord(filter, record);
      }
    }

    // handle record in transaction first
    if (_hasTransactionRecords(txn)) {
      // Copy for cooperate
      var records = txnCurrentRecords;
      for (var record in records) {
        if (needCooperate) {
          await cooperate();
        }

        if (_filterMatchRecord(filter, record)) {
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
        if (txnRecords.keys.contains(record.key)) {
          // already handled
          continue;
        }
      }
      if (_filterMatchRecord(filter, record)) {
        if (action(record) == false) {
          return;
        }
      }
    }
  }

  ///
  /// find the first matching record
  ///
  @override
  Future<Record> findRecord(Finder finder) async {
    return makeOutRecord(await txnFindRecord(null, finder));
  }

  @override
  Future findKey(Finder finder) async => (await findRecord(finder))?.key;

  Future txnFindKey(SembastTransaction txn, Finder finder) async =>
      (await txnFindRecord(txn, finder))?.key;

  Future<ImmutableSembastRecord> txnFindRecord(
      SembastTransaction txn, Finder finder) async {
    if (finder != null) {
      if ((finder as SembastFinder).limit != 1) {
        finder = (finder as SembastFinder).clone(limit: 1);
      }
    } else {
      finder = SembastFinder(limit: 1);
    }
    var records = await txnFindRecords(txn, finder);
    if (records.isNotEmpty) {
      return records.first;
    }
    return null;
  }

  Future<List<ImmutableSembastRecord>> filterStart(
      SembastFinder finder, List<ImmutableSembastRecord> results) async {
    int startIndex = 0;
    for (int i = 0; i < results.length; i++) {
      if (needCooperate) {
        await cooperate();
      }
      if (finder.starts(results[i], finder.start)) {
        startIndex = i;
        break;
      }
    }
    if (startIndex != 0) {
      return results.sublist(startIndex);
    }
    return results;
  }

  Future<List<ImmutableSembastRecord>> filterEnd(
      SembastFinder finder, List<ImmutableSembastRecord> results) async {
    int endIndex = 0;
    for (int i = results.length - 1; i >= 0; i--) {
      if (needCooperate) {
        await cooperate();
      }
      if (finder.ends(results[i], finder.end)) {
        // continue
      } else {
        endIndex = i + 1;
        break;
      }
    }
    if (endIndex != results.length) {
      return results.sublist(0, endIndex);
    }
    return results;
  }

  ///
  /// find all records
  ///
  @override
  Future<List<Record>> findRecords(Finder finder) async {
    return await makeOutRecords(await txnFindRecords(null, finder));
  }

  Future<List<ImmutableSembastRecord>> txnFindRecords(
      SembastTransaction txn, Finder finder) async {
    List<ImmutableSembastRecord> results = [];

    var sembastFinder = finder as SembastFinder;

    await forEachRecords(txn, sembastFinder?.filter, (record) {
      results.add(record);
      return true;
    });

    if (finder != null) {
      // sort
      if (cooperateOn) {
        var sort = Sort(database.cooperator);
        await sort.sort(
            results,
            (Record record1, Record record2) =>
                sembastFinder.compareThenKey(record1, record2));
      } else {
        results.sort((record1, record2) =>
            sembastFinder.compareThenKey(record1, record2));
      }

      try {
        // handle start
        if (sembastFinder.start != null) {
          results = await filterStart(sembastFinder, results);
        }
        // handle end
        if (sembastFinder.end != null) {
          results = await filterEnd(sembastFinder, results);
        }
      } catch (e) {
        print('Make sure you are comparing boundaries with a proper type');
        rethrow;
      }

      // offset
      if (sembastFinder.offset != null) {
        results = results.sublist(min(sembastFinder.offset, results.length));
      }
      // limit
      if (sembastFinder.limit != null) {
        results = results.sublist(0, min(sembastFinder.limit, results.length));
      }
    } else {
      if (cooperateOn) {
        var sort = Sort(database.cooperator);
        await sort.sort(results, compareRecordKey);
      } else {
        results.sort(compareRecordKey);
      }
    }
    return results;
  }

  @override
  Future<List> findKeys(Finder finder) async {
    return txnFindKeys(null, finder);
  }

  Future<List> txnFindKeys(SembastTransaction txn, Finder finder) async {
    var records = await txnFindRecords(txn, finder);
    return records.map((Record record) => record.key).toList();
  }

  ///
  /// return true if it existed before
  ///
  bool setRecordInMemory(ImmutableSembastRecord record) {
    //SembastStore store = record.store as SembastStore;
    bool exists = recordMap[record.key] != null;
    if (record.deleted) {
      recordMap.remove(record.key);
    } else {
      recordMap[record.key] = record;
    }
    return exists;
  }

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

  ///
  /// Put a record
  ///
  Future<Record> putRecord(Record record) {
    return transaction((txn) async {
      return makeOutRecord(
          await txnPutRecord(txn as SembastTransaction, record));
    });
  }

  Future<ImmutableSembastRecord> txnPutRecord(
      SembastTransaction txn, Record record) async {
    await cooperate();
    return txnPutRecordSync(txn, record);
  }

  ImmutableSembastRecord txnPutRecordSync(
      SembastTransaction txn, Record record) {
    var sembastRecord = makeImmutableRecord(record);

    // auto-gen key if needed
    if (sembastRecord.key == null) {
      sembastRecord.ref = ref.record(++lastIntKey);
    } else {
      // update last int key in case auto gen is needed again
      var recordKey = sembastRecord.key;
      if (recordKey is int) {
        int intKey = recordKey;
        if (intKey > lastIntKey) {
          lastIntKey = intKey;
        }
      }
    }
    // add to store transaction
    checkTransaction(txn);
    if (txnRecords == null) {
      txnRecords = <dynamic, TxnRecord>{};
    }
    txnRecords[sembastRecord.key] = TxnRecord(this, sembastRecord);
    return sembastRecord;
  }

  ImmutableSembastRecord _getRecord(SembastTransaction txn, var key) {
    ImmutableSembastRecord record;

    // look in current transaction
    checkTransaction(txn);
    if (_hasTransactionRecords(txn)) {
      record = txnRecords[key]?.record;
    }

    if (record == null) {
      record = recordMap[key];
    }
    if (database.logV) {
      SembastDatabase.logger
          .fine("${database.currentTransaction} get ${record} key ${key}");
    }
    return record;
  }

  ///
  /// get a record by key
  ///
  @override
  Future<Record> getRecord(var key) async {
    return makeOutRecord(await txnGetRecord(null, key));
  }

  /// cooperate safe
  Record makeOutRecord(ImmutableSembastRecord record) =>
      record_impl.makeLazyMutableRecord(this, record);

  /// cooperate safe
  Future<List<Record>> makeOutRecords(
      List<ImmutableSembastRecord> records) async {
    if (records != null) {
      var clones = <Record>[];
      // make it safe for the loop
      records = List<ImmutableSembastRecord>.from(records, growable: false);
      for (var record in records) {
        if (needCooperate) {
          await cooperate();
        }
        clones.add(record_impl.makeLazyMutableRecord(this, record));
      }
      return clones;
    }
    return null;
  }

  Future<ImmutableSembastRecord> txnGetRecord(
      SembastTransaction txn, key) async {
    var record = txnGetRecordSync(txn, key);
    // Cooperate after!
    if (needCooperate) {
      await cooperate();
    }
    return record;
  }

  Future<bool> txnRecordExists(SembastTransaction txn, key) async {
    var record = _getRecord(txn, key);
    // Cooperate after!
    if (needCooperate) {
      await cooperate();
    }
    return (record?.deleted == false);
  }

  ImmutableSembastRecord txnGetRecordSync(SembastTransaction txn, key) {
    var record = _getRecord(txn, key);
    if (record == null || record.deleted) {
      return null;
    }
    return record;
  }

  ///
  /// Get all records from a list of keys
  ///
  @override
  Future<List<Record>> getRecords(Iterable keys) async {
    return makeOutRecords(await txnGetRecordsCompat(null, keys));
  }

  /// Return records ignoring non found ones and deleted
  Future<List<ImmutableSembastRecord>> txnGetRecordsCompat(
      SembastTransaction txn, Iterable keys) async {
    List<ImmutableSembastRecord> records = [];

    for (var key in keys) {
      var record = _getRecord(txn, key);
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
  Future<List<RecordSnapshot<K, V>>> txnGetRecordSnapshots<K, V>(
      SembastTransaction txn, RecordsRef<K, V> refs) async {
    List<RecordSnapshot<K, V>> snapshots = [];

    for (var key in refs.keys) {
      var immutable = _getRecord(txn, key);
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

  ///
  /// get a value from a key
  ///
  @override
  Future get(var key) async {
    return cloneValue(await txnGet(null, key));
  }

  Future<dynamic> txnGet(SembastTransaction txn, key) async {
    Record record = await txnGetRecord(txn, key);
    return record?.value;
  }

  ///
  /// count all records
  ///
  @override
  Future<int> count([Filter filter]) async {
    return await txnCount(null, filter);
  }

  Future<int> txnCount(SembastTransaction txn, Filter filter) async {
    int count = 0;
    await forEachRecords(txn, filter, (record) {
      count++;
      return true;
    });
    return count;
  }

  @override
  Future delete(var key) {
    return transaction((txn) {
      return txnDelete(txn as SembastTransaction, key);
    });
  }

  Future<dynamic> txnDelete(SembastTransaction txn, var key) async {
    var record = _getRecord(txn, key);
    await cooperate();
    if (record == null) {
      return null;
    } else {
      // Do the deletion
      // clone and mark as deleted
      var clone = record.sembastClone(deleted: true);
      await txnPutRecord(txn, clone);
      return record.key;
    }
  }

  ///
  /// return the list of deleted keys
  ///
  @override
  Future deleteAll(Iterable keys) {
    return transaction((txn) {
      return txnDeleteAll(txn as SembastTransaction, keys);
    });
  }

  Future<List> txnDeleteAll(SembastTransaction txn, Iterable keys) async {
    List<Record> updates = [];
    List deletedKeys = [];

    // make it safe in a async way
    keys = List.from(keys, growable: false);
    for (var key in keys) {
      await cooperate();
      var record = _getRecord(txn, key);
      if (record != null && !record.deleted) {
        // Clone and mark deleted
        Record clone = record.sembastClone(deleted: true);

        updates.add(clone);
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

  Future<List> txnUpdateAll(
      SembastTransaction txn, dynamic value, Iterable keys) async {
    List<Record> updates = [];
    List deletedKeys = [];

    // make it safe in a async way
    keys = List.from(keys, growable: false);
    for (var key in keys) {
      await cooperate();
      var record = _getRecord(txn, key);
      if (record != null && !record.deleted) {
        // Clone and mark deleted
        Record clone = record.sembastClone(deleted: true);

        updates.add(clone);
        deletedKeys.add(key);
      }
    }

    if (updates.isNotEmpty) {
      await database.txnPutRecords(txn, updates);
    }
    return deletedKeys;
  }

  @override
  Future<bool> containsKey(key) async {
    return txnContainsKey(null, key);
  }

  bool _hasTransactionRecords(SembastTransaction txn) {
    return txn != null && txn == currentTransaction && txnRecords != null;
  }

  bool txnContainsKey(SembastTransaction txn, key) {
    if (recordMap.containsKey(key)) {
      return true;
    } else if (_hasTransactionRecords(txn)) {
      return txnRecords.containsKey(key);
    } else {
      return false;
    }
  }

  void rollback() {
    // clear map;
    txnRecords = null;
  }

  ///
  /// debug json
  ///
  Map toJson() {
    Map map = {};
    if (name != null) {
      map["name"] = name;
    }
    if (recordMap != null) {
      map["count"] = recordMap.length;
    }
    return map;
  }

  @override
  String toString() {
    return "${name}";
  }

  ///
  /// delete all records in a store
  ///
  ///
  @override
  Future clear() {
    return transaction((txn) {
      // first delete the one in transaction
      return txnClear(txn as SembastTransaction);
    });
  }

  Future<List> txnClear(SembastTransaction txn, {Finder finder}) async {
    if (finder == null) {
      var deletedKeys = [];
      if (_hasTransactionRecords(txn)) {
        deletedKeys.addAll(await txnDeleteAll(
            txn, List.from(txnRecords.keys, growable: false)));
      }
      Iterable keys = recordMap.keys;
      deletedKeys
          .addAll(await txnDeleteAll(txn, List.from(keys, growable: false)));
      return deletedKeys;
    } else {
      var keys = await txnFindKeys(txn, finder);
      return await txnDeleteAll(txn, List.from(keys, growable: false));
    }
  }

  Future<List> txnUpdateWhere(SembastTransaction txn, dynamic value,
      {Finder finder}) async {
    var keys = await txnFindKeys(txn, finder);
    for (var key in keys) {
      await txnPut(txn, value, key, merge: true);
    }
    return keys;
  }

  //
// Cooperate mode
//
  bool get needCooperate => database.needCooperate;

  bool get cooperateOn => database.cooperateOn;

  FutureOr cooperate() => database.cooperate();
}
