import 'dart:async';

import 'package:sembast/sembast.dart';

///
/// Method shared by Store and Database (main store)
abstract class BaseExecutor {
  Store get store;

  ///
  /// get a value from a key
  /// null if not found or if value null
  ///
  Future get(dynamic key);

  ///
  /// count all records
  ///
  Future<int> count([Filter filter]);

  ///
  /// put a value with an optional key
  ///
  Future put(dynamic value, [dynamic key]);

  ///
  /// Update an existing record with the given key
  /// if value is a map, existing fields are replaced but not removed unless
  /// specified
  ///
  Future update(dynamic value, dynamic key);

  ///
  /// delete a record by key
  ///
  Future delete(dynamic key);

  ///
  /// find the first matching record
  ///
  Future<Record> findRecord(Finder finder);

  ///
  /// find all records
  ///
  Future<List<Record>> findRecords(Finder finder);

  /// new in 1.7.1
  Future<bool> containsKey(dynamic key);

  /// new in 1.9.0
  Future<List> findKeys(Finder finder);

  /// new in 1.9.0
  Future findKey(Finder finder);
}

abstract class StoreExecutor extends BaseExecutor {
  ///
  /// delete all records in a store
  ///
  Future clear();

  ///
  /// get a record by key
  ///
  Future<Record> getRecord(dynamic key);

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

abstract class Store extends StoreExecutor {
  ///
  /// Store name
  ///
  String get name;
}
