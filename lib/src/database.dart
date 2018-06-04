import 'dart:async';

import 'package:sembast/sembast.dart';

abstract class Database extends StoreExecutor {
  /// Version of the database
  int get version;

  /// Database  path
  String get path;

  ///
  /// execute the action in a transaction
  /// use the current if any
  ///
  Future<T> inTransaction<T>(FutureOr<T> action());

  /// All the stores in the database
  Iterable<Store> get stores;

  /// The main store used
  Store get mainStore;

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
  /// Put a record
  ///
  Future<Record> putRecord(Record record);

  ///
  /// Put a list or records
  ///
  Future<List<Record>> putRecords(List<Record> records);

  ///
  /// delete a [record]
  ///
  Future deleteRecord(Record record);

  ///
  /// The current transaction when in inTransaction
  /// Might be deprecated soon
  @deprecated
  Transaction get transaction;

  // deprecated since 2018-03-05 1.7.0
  @deprecated
  Map toJson();

  ///
  /// Close the database
  ///
  close();
}
