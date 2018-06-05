import 'dart:async';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/store_impl.dart';

abstract class DatabaseExecutorMixin
    implements DatabaseExecutor, StoreExecutor {
  SembastDatabase get database;
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

abstract class TransactionExecutorMixin implements TransactionExecutor {
  SembastDatabase get database;
  SembastTransaction get transaction;

  @override
  Future<Record> putRecord(Record record) async =>
      database.txnPutRecord(transaction, record);
}

class SembastTransaction extends Object
    with DatabaseExecutorMixin, TransactionExecutorMixin
    implements Transaction {
  final SembastDatabase database;

  int get id => _id;

  final int _id;

  // make the completer async as the Transaction following
  // action is not a priority
  Completer completer = new Completer();

  SembastTransaction(this.database, this._id);

  bool get isCompleted => completer.isCompleted;

  Future get completed => completer.future;

  @override
  String toString() {
    return "txn ${_id}${completer.isCompleted ? ' completed' : ''}";
  }

  @override
  StoreExecutor get mainStore => toExecutor(database.mainStore);

  @override
  SembastTransaction get transaction => this;

  SembastTransactionStore toExecutor(Store store) => store != null
      ? new SembastTransactionStore(this, store as SembastStore)
      : null;

  @override
  Future clear() => mainStore.clear();

  @override
  Iterable<StoreExecutor> get stores =>
      database.stores.map((store) => toExecutor(store));

  @override
  Future deleteStore(String storeName) async =>
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
  Future<List<Record>> putRecords(List<Record> records) async =>
      database.txnPutRecords(this, records);
}

class SembastTransactionStore implements StoreTransaction {
  final SembastTransaction transaction;
  final SembastStore store;

  SembastTransactionStore(this.transaction, this.store);

  @override
  Future<bool> containsKey(key) async => store.txnContainsKey(transaction, key);

  @override
  Future<int> count([Filter filter]) async =>
      store.txnCount(transaction, filter);

  @override
  Future delete(key) async => store.txnDelete(transaction, key);

  @override
  Future<Record> findRecord(Finder finder) async =>
      store.txnFindRecord(transaction, finder);

  @override
  Future<List<Record>> findRecords(Finder finder) async =>
      store.txnFindRecords(transaction, finder);

  @override
  Future get(key) async => store.txnGet(transaction, key);

  @override
  Future put(value, [key]) async => store.txnPut(transaction, value, key);

  @override
  Future clear() async => store.txnClear(transaction);

  @override
  Future deleteAll(Iterable keys) async =>
      store.txnDeleteAll(transaction, keys);

  @override
  Future<Record> getRecord(key) async => store.txnGetRecord(transaction, key);

  @override
  Future<List<Record>> getRecords(Iterable keys) async =>
      store.txnGetRecords(transaction, keys);

  @override
  Stream<Record> get records => store.txnGetRecordsStream(transaction);

  @override
  Future findKey(Finder finder) => store.txnFindKey(transaction, finder);

  @override
  Future<List> findKeys(Finder finder) =>
      store.txnFindKeys(transaction, finder);
}
