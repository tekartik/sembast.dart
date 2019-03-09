import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/client.dart';
import 'package:sembast/src/api/finder.dart';
import 'package:sembast/src/api/record_ref.dart';
import 'package:sembast/src/api/record_snapshot.dart';
import 'package:sembast/src/store/store_ref_impl.dart';
// New in 1.15

/// A pointer to a store
abstract class StoreRef<K, V> {
  /// The name of the store
  String get name;

  /// Create a record reference
  RecordRef<K, V> record(K key);

  factory StoreRef(String name) => StoreRefBase(name);

  ///
  /// delete all records in a store
  ///
  Future clear(DatabaseClient client);

  ///
  /// Get all records from a list of keys
  ///
  Future<List<RecordSnapshot<K, V>>> getAll(
      DatabaseClient client, Iterable<K> keys);

  ///
  /// return the list of deleted keys
  ///
  Future deleteAll(DatabaseClient client, Iterable<K> keys);

  /// Cast if needed
  StoreRef<RK, RV> cast<RK, RV>();

  ///
  /// Find a single record
  ///
  Future<RecordSnapshot<K, V>> find(DatabaseClient client, Finder finder);
}

///
abstract class StoreFactory<K, V> {
  StoreRef<K, V> store(String name);
}

/// common `<int, Map<String, dynamic>>` factory
final intMapStoreFactory = StoreFactoryBase<int, Map<String, dynamic>>();

/// common `<String, Map<String, dynamic>>` factory
final stringMapStoreFactory = StoreFactoryBase<String, Map<String, dynamic>>();
