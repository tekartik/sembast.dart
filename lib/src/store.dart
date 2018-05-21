import 'dart:async';

import 'package:sembast/sembast.dart';

///
/// Method shared by Store and Database (main store)
abstract class StoreExecutor {
  ///
  /// get a value from a key
  /// null if not found or if value null
  ///
  Future get(var key);

  ///
  /// count all records
  ///
  Future<int> count([Filter filter]);

  ///
  /// put a value with an optional key
  ///
  Future put(var value, [var key]);

  ///
  /// delete a record by key
  ///
  Future delete(var key);

  ///
  /// find the first matching record
  ///
  Future<Record> findRecord(Finder finder);

  ///
  /// find all records
  ///
  Future<List<Record>> findRecords(Finder finder);

  /// new in 1.7.1
  Future<bool> containsKey(var key);
}

abstract class Store extends StoreExecutor {
  ///
  /// Store name
  ///
  String get name;

  ///
  /// delete all records in a store
  ///
  Future clear();

  ///
  /// put a record and return the key
  ///
  Future put(var value, [var key]);

  ///
  /// get a record by key
  ///
  Future<Record> getRecord(var key);

  ///
  /// Get all records from a list of keys
  ///
  Future<List<Record>> getRecords(Iterable keys);

  ///
  /// return the list of deleted keys
  ///
  Future deleteAll(Iterable keys);

  ///
  /// stream all the records
  ///
  Stream<Record> get records;
}
