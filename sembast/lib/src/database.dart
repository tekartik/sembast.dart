import 'dart:async';

import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_store.dart' show DatabaseClient;

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

abstract class DatabaseExecutor extends StoreExecutor {
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
}

abstract class Database extends DatabaseExecutor implements DatabaseClient {
  Store get mainStore;

  /// Version of the database
  int get version;

  /// Database  path
  String get path;

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

  ///
  /// execute the action in a transaction
  /// use the current if any
  ///
  Future<T> transaction<T>(FutureOr<T> action(Transaction transaction));

  ///
  /// Close the database
  ///
  Future close();
}
