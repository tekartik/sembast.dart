import 'dart:async';
import 'package:sembast/src/api/compat/sembast.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/src/database_client_impl.dart';
import 'package:sembast/src/database_impl.dart';
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

  /// Get a value from a key
  Future get(key) => (mainStore as SembastTransactionStore).get(key);

  @override
  Future put(value, [key]) =>
      (mainStore as SembastTransactionStore).put(value, key);

  @override
  Future update(value, key) => mainStore.update(value, key);

  @override
  Store get store => mainStore.store;
}

/// Transaction implementation.
class SembastTransaction extends Object
    with DatabaseExecutorMixin
    implements Transaction, SembastDatabaseClient {
  /// The database.
  @override
  final SembastDatabase sembastDatabase;

  /// The transaction id.
  int get id => _id;

  final int _id;

  /// make the completer async as the Transaction following
  /// action is not a priority
  Completer completer = Completer();

  /// Constructor.
  SembastTransaction(this.sembastDatabase, this._id);

  /// True if completed.
  bool get isCompleted => completer.isCompleted;

  /// Completed future.
  Future get completed => completer.future;

  @override
  String toString() {
    return 'txn ${_id}${completer.isCompleted ? ' completed' : ''}';
  }

  @override
  StoreExecutor get mainStore => toExecutor(database.mainStore);

  /// Make it an executor.
  SembastTransactionStore toExecutor(Store store) => store != null
      ? SembastTransactionStore(this, store as SembastStore)
      : null;

  @override
  Iterable<SembastTransactionStore> get stores =>
      database.stores.map(toExecutor);

  /// Delete a store
  Future deleteStore(String storeName) =>
      database.txnDeleteStore(this, storeName);

  /// Find a store
  StoreExecutor findStore(String storeName) =>
      database.txnFindStore(this, storeName);

  @override
  StoreExecutor getStore(String storeName) =>
      database.txnGetStore(this, storeName);

  /// Store implementation.
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

/// Store implementation.
class SembastTransactionStore implements StoreTransaction {
  /// Transaction.
  final SembastTransaction sembastTransaction;
  @override
  final SembastStore store;

  /// Constructor.
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

  /// Get a value from a key
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
  Future findKey(Finder finder) => store.txnFindKey(sembastTransaction, finder);

  @override
  Future<List> findKeys(Finder finder) =>
      store.txnFindKeys(sembastTransaction, finder);

  @override
  String toString() {
    return '${store}';
  }
}
