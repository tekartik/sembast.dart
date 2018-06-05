import 'dart:async';

import 'package:sembast/sembast.dart';

abstract class TransactionExecutor extends DatabaseExecutor {
  /// The main store used
  StoreExecutor get mainStore;

  /// All the stores in the database
  Iterable<StoreExecutor> get stores;

  ///
  /// get or create a store
  /// an empty store will not be persistent
  ///
  StoreExecutor getStore(String storeName);

  ///
  /// clear and delete a store
  ///
  Future deleteStore(String storeName);

  ///
  /// find existing store
  ///
  StoreExecutor findStore(String storeName);
}

abstract class DatabaseExecutor extends BaseExecutor {
  ///
  /// Put a record
  ///
  Future<Record> putRecord(Record record);
}

abstract class Database extends DatabaseExecutor {
  Store get mainStore;

  /// Version of the database
  int get version;

  /// Database  path
  String get path;

  ///
  /// execute the action in a transaction
  /// use the current if any
  ///
  @deprecated
  Future<T> inTransaction<T>(FutureOr<T> action());

  /// All the stores in the database
  Iterable<Store> get stores;

  ///
  /// get or create a store
  /// an empty store will not be persistent
  ///
  Store getStore(String storeName);

  ///
  /// clear and delete a store
  ///
  Future deleteStore(String storeName);

  ///
  /// find existing store
  ///
  Store findStore(String storeName);

  // deprecated since 2018-03-05 1.7.0
  // use [Store.getRecord]
  @deprecated
  Future<Record> getStoreRecord(Store store, var key);

  // deprecated since 2018-03-05 1.7.0
  // use [Store.findRecord]
  @deprecated
  Future<List<Record>> findStoreRecords(Store store, Finder finder);

  ///
  /// Put a list or records
  ///
  Future<List<Record>> putRecords(List<Record> records);

  ///
  /// delete a [record]
  ///
  Future deleteRecord(Record record);

  ///
  /// execute the action in a transaction
  /// use the current if any
  ///
  Future<T> transaction<T>(FutureOr<T> action(Transaction transaction));

  // deprecated since 2018-03-05 1.7.0
  @deprecated
  Map toJson();

  ///
  /// Close the database
  ///
  close();
}
