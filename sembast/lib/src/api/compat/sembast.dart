import 'package:sembast/src/api/compat/record.dart';
import 'package:sembast/src/api/compat/store.dart';
import 'package:sembast/src/api/filter.dart';
import 'package:sembast/src/api/finder.dart';
import 'package:sembast/src/api/sembast.dart';

export 'package:sembast/src/api/compat/database_mode.dart';
export 'package:sembast/src/api/compat/finder.dart';
export 'package:sembast/src/api/compat/record.dart';
export 'package:sembast/src/api/compat/store.dart';
export 'package:sembast/src/api/database.dart';

/// @deprecated v2
abstract class TransactionExecutor extends DatabaseExecutor {
  /// @deprecated v2
  ///
  /// The main store used
  StoreExecutor get mainStore;

  /// @deprecated v2
  ///
  /// All the stores in the database
  Iterable<StoreExecutor> get stores;

  /// @deprecated v2
  ///
  /// get or create a store
  /// an empty store will not be persistent
  ///
  StoreExecutor getStore(String storeName);

  /// @deprecated v2
  ///
  /// clear and delete a store
  ///
  Future deleteStore(String storeName);

  /// @deprecated v2
  ///
  /// find existing store
  ///
  StoreExecutor findStore(String storeName);
}

/// @deprecated v2
abstract class DatabaseExecutor extends StoreExecutor {
  /// @deprecated v2
  ///
  /// Put a record
  ///
  Future<Record> putRecord(Record record);

  /// @deprecated v2
  ///
  /// Put a list or records
  ///
  Future<List<Record>> putRecords(List<Record> records);

  /// @deprecated v2
  ///
  /// delete a [record]
  ///
  Future deleteRecord(Record record);
}

/// @deprecated v2
abstract class StoreExecutor extends BaseExecutor {
  /// @deprecated v2
  ///
  /// delete all records in a store
  ///
  Future clear();

  /// @deprecated v2
  ///
  /// get a record by key
  ///
  Future<Record> getRecord(dynamic key);

  /// @deprecated v2
  ///
  /// Get all records from a list of keys
  ///
  Future<List<Record>> getRecords(Iterable keys);

  /// @deprecated v2
  ///
  /// return the list of deleted keys
  ///
  Future deleteAll(Iterable keys);

  /// @deprecated v2
  ///
  /// stream all the records
  ///
  Stream<Record> get records;
}

/// @deprecated v2
///
/// Method shared by Store and Database (main store)
///
abstract class BaseExecutor {
  /// @deprecated v2
  Store get store;

  /// @deprecated v2
  ///
  /// get a value from a key
  /// null if not found or if value null
  ///
  Future get(dynamic key);

  /// @deprecated v2
  ///
  /// count all records
  ///
  Future<int> count([Filter filter]);

  /// @deprecated v2
  ///
  /// put a value with an optional key. Returns the key
  ///
  Future put(dynamic value, [dynamic key]);

  /// @deprecated v2
  ///
  /// Update an existing record if any with the given key
  /// if value is a map, existing fields are replaced but not removed unless
  /// specified ([FieldValue.delete])
  ///
  /// Does not do anything if the record does not exist
  ///
  /// Returns the record value (merged) or null if the record was not found
  ///
  Future update(dynamic value, dynamic key);

  /// @deprecated v2
  ///
  /// delete a record by key
  ///
  Future delete(dynamic key);

  /// @deprecated v2
  ///
  /// find the first matching record
  ///
  Future<Record> findRecord(Finder finder);

  /// @deprecated v2
  ///
  /// find all records
  ///
  Future<List<Record>> findRecords(Finder finder);

  /// @deprecated v2
  Future<bool> containsKey(dynamic key);

  /// @deprecated v2
  Future<List> findKeys(Finder finder);

  /// @deprecated v2
  Future findKey(Finder finder);
}

//import 'package:tekartik_core/dev_utils.dart';
/// @deprecated v2
abstract class StoreTransaction extends StoreExecutor {}
