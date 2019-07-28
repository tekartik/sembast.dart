import 'dart:async';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/database_client_impl.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/store_impl.dart';
import 'package:sembast/src/utils.dart';

// ignore_for_file: deprecated_member_use_from_same_package

mixin DatabaseExecutorMixin implements DatabaseExecutor, StoreExecutor {
  StoreExecutor get mainStore;

  @override
  Future<bool> containsKey(key) => mainStore.containsKey(key);

  @override
  Future<int> count([Filter filter]) => mainStore.count(filter);

  @override
  Future delete(key) => mainStore.delete(key);

  @override
  Future<Record> findRecord(Finder finder) => mainStore.findRecord(finder);

  @override
  Future findKey(Finder finder) => mainStore.findKey(finder);

  @override
  Future<List<Record>> findRecords(Finder finder) =>
      mainStore.findRecords(finder);

  @override
  Future<List> findKeys(Finder finder) => mainStore.findKeys(finder);

  @override
  Future get(key) => mainStore.get(key);

  @override
  Future put(value, [key]) => mainStore.put(value, key);

  @override
  Future update(value, key) => mainStore.update(value, key);

  @override
  Store get store => mainStore.store;

  @override
  Future deleteAll(Iterable keys) => mainStore.deleteAll(keys);

  @override
  Future<Record> getRecord(key) => mainStore.getRecord(key);

  @override
  Future<List<Record>> getRecords(Iterable keys) => mainStore.getRecords(keys);

  @override
  Stream<Record> get records => mainStore.records;
}

class SembastTransaction extends Object
    with DatabaseExecutorMixin
    implements Transaction, SembastDatabaseClient {
  @override
  final SembastDatabase sembastDatabase;

  int get id => _id;

  final int _id;

  // make the completer async as the Transaction following
  // action is not a priority
  Completer completer = Completer();

  SembastTransaction(this.sembastDatabase, this._id);

  bool get isCompleted => completer.isCompleted;

  Future get completed => completer.future;

  @override
  String toString() {
    return "txn ${_id}${completer.isCompleted ? ' completed' : ''}";
  }

  @override
  StoreExecutor get mainStore => toExecutor(database.mainStore);

  SembastTransactionStore toExecutor(Store store) => store != null
      ? SembastTransactionStore(this, store as SembastStore)
      : null;

  @override
  Future clear() => mainStore.clear();

  @override
  Iterable<SembastTransactionStore> get stores =>
      database.stores.map(toExecutor);

  @override
  Future deleteStore(String storeName) =>
      database.txnDeleteStore(this, storeName);

  @override
  StoreExecutor findStore(String storeName) =>
      database.txnFindStore(this, storeName);

  @override
  StoreExecutor getStore(String storeName) =>
      database.txnGetStore(this, storeName);

  @override
  Future deleteRecord(Record record) async =>
      (record.store as SembastStore).txnDelete(this, record.key);

  @override
  Future<Record> putRecord(Record record) async =>
      database.makeOutRecord(await database.txnPutRecord(this, record));

  @override
  Future<List<Record>> putRecords(List<Record> records) async =>
      database.makeOutRecords(await database.txnPutRecords(this, records));

  SembastTransactionStore recordStore(Record record) =>
      (record.store ?? mainStore) as SembastTransactionStore;

  /// local helper
  SembastDatabase get database => sembastDatabase;

  @override
  Future<T> inTransaction<T>(
          FutureOr<T> Function(SembastTransaction transaction) action) async =>
      action(this);

  @override
  SembastTransaction get sembastTransaction => this;

  @override
  SembastStore getSembastStore(StoreRef ref) =>
      database.txnGetStore(this, ref.name).store;
}

class SembastTransactionStore implements StoreTransaction {
  final SembastTransaction sembastTransaction;
  @override
  final SembastStore store;

  SembastTransactionStore(this.sembastTransaction, this.store);

  @override
  Future<bool> containsKey(key) async =>
      store.txnContainsKey(sembastTransaction, key);

  @override
  Future<int> count([Filter filter]) =>
      store.txnCount(sembastTransaction, filter);

  @override
  Future delete(key) async => store.txnDelete(sembastTransaction, key);

  @override
  Future<Record> findRecord(Finder finder) async => store
      .makeOutRecord(await store.txnFindRecord(sembastTransaction, finder));

  @override
  Future<List<Record>> findRecords(Finder finder) async => store
      .makeOutRecords(await store.txnFindRecords(sembastTransaction, finder));

  @override
  Future get(key) async =>
      cloneValue(await store.txnGet(sembastTransaction, key));

  @override
  Future put(value, [key]) {
    if (key == null) {
      return store.txnAdd(sembastTransaction, value);
    } else {
      return store.txnPut(sembastTransaction, value, key).then((_) => key);
    }
  }

  @override
  Future update(value, key) async =>
      cloneValue(await store.txnUpdate(sembastTransaction, value, key));

  @override
  Future clear() async => store.txnClear(sembastTransaction);

  @override
  Future deleteAll(Iterable keys) async =>
      store.txnDeleteAll(sembastTransaction, keys);

  @override
  Future<Record> getRecord(key) async => makeLazyMutableRecord(
      store, await store.txnGetRecord(sembastTransaction, key));

  @override
  Future<List<Record>> getRecords(Iterable keys) async =>
      await store.makeOutRecords(
          await store.txnGetRecordsCompat(sembastTransaction, keys));

  @override
  Stream<Record> get records => store.txnGetRecordsStream(sembastTransaction);

  @override
  Future findKey(Finder finder) => store.txnFindKey(sembastTransaction, finder);

  @override
  Future<List> findKeys(Finder finder) =>
      store.txnFindKeys(sembastTransaction, finder);

  @override
  String toString() {
    return "${store}";
  }
}
