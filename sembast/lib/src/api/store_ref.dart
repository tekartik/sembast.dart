import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/client.dart';
import 'package:sembast/src/api/finder.dart';
import 'package:sembast/src/api/record_ref.dart';
import 'package:sembast/src/api/record_snapshot.dart';
import 'package:sembast/src/api/records_ref.dart';
import 'package:sembast/src/sembast_impl.dart';
import 'package:sembast/src/store_ref_impl.dart';
// New in 1.15

/// A pointer to a store
abstract class StoreRef<K, V> {
  /// The name of the store
  String get name;

  /// Create a record reference.
  ///
  /// Key cannot be null
  RecordRef<K, V> record(K key);

  /// Create a reference to multiple records
  ///
  RecordsRef<K, V> records(Iterable<K> keys);

  /// A null name means a the main store
  ///
  /// A name must not start with _
  factory StoreRef(String name) => StoreRefBase(name);

  /// A pointer to the main store
  factory StoreRef.main() => StoreRefBase(dbMainStore);

  /// Delete the store and its content
  Future delete(DatabaseClient client);

  ///
  /// delete all records in a store
  ///
  Future clear(DatabaseClient client);

  /// Cast if needed
  StoreRef<RK, RV> cast<RK, RV>();

  ///
  /// Find a single record
  ///
  Future<RecordSnapshot<K, V>> findRecord(DatabaseClient client,
      {Finder finder});

  ///
  /// Find multiple records. Return an empty array if none found
  ///
  Future<List<RecordSnapshot<K, V>>> find(DatabaseClient client,
      {Finder finder});

  ///
  /// count all records
  ///
  Future<int> count(DatabaseClient client, {Filter filter});

  ///
  /// Add a record, returns its generated int key
  ///
  Future<K> add(DatabaseClient client, V value);
}

///
abstract class StoreFactory<K, V> {
  StoreRef<K, V> store(String name);
}

/// common `<int, Map<String, dynamic>>` factory
final intMapStoreFactory = StoreFactoryBase<int, Map<String, dynamic>>();

/// common `<String, Map<String, dynamic>>` factory
final stringMapStoreFactory = StoreFactoryBase<String, Map<String, dynamic>>();
