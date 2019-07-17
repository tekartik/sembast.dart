import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/client.dart';
import 'package:sembast/src/api/finder.dart';
import 'package:sembast/src/api/query_ref.dart';
import 'package:sembast/src/api/record_ref.dart';
import 'package:sembast/src/api/record_snapshot.dart';
import 'package:sembast/src/api/records_ref.dart';
import 'package:sembast/src/sembast_impl.dart';
import 'package:sembast/src/store_ref_impl.dart';
// New in 1.15

/// A pointer to a store.
///
/// Provides access helper to data on the store using a given [DatabaseClient].
///
abstract class StoreRef<K, V> {
  /// The name of the store
  String get name;

  /// Create a record reference.
  ///
  /// Key cannot be null.
  RecordRef<K, V> record(K key);

  /// Create a reference to multiple records
  ///
  RecordsRef<K, V> records(Iterable<K> keys);

  /// A null name means a the main store.
  ///
  /// A name must not start with `_` (besides the main store).
  factory StoreRef(String name) => SembastStoreRef(name);

  /// A pointer to the main store
  factory StoreRef.main() => SembastStoreRef(dbMainStore);

  /// Delete the store and its content
  Future drop(DatabaseClient client);

  /// Cast if needed
  StoreRef<RK, RV> cast<RK, RV>();

  ///
  /// Find a single record
  ///
  Future<RecordSnapshot<K, V>> findFirst(DatabaseClient client,
      {Finder finder});

  ///
  /// Find multiple records.
  ///
  /// Returns an empty array if none found.
  ///
  Future<List<RecordSnapshot<K, V>>> find(DatabaseClient client,
      {Finder finder});

  ///
  /// Create a query with a finder.
  ///
  QueryRef<K, V> query({Finder finder});

  ///
  /// Find one key.
  ///
  /// Returns null if not found.
  ///
  Future<K> findKey(DatabaseClient client, {Finder finder});

  ///
  /// Find multiple keys.
  ///
  /// Return an empty array if none found.
  ///
  Future<List<K>> findKeys(DatabaseClient client, {Finder finder});

  /// Unsorted record stream
  Stream<RecordSnapshot<K, V>> stream(DatabaseClient client, {Filter filter});

  ///
  /// count records.
  ///
  Future<int> count(DatabaseClient client, {Filter filter});

  ///
  /// Add a record, returns its generated key.
  ///
  Future<K> add(DatabaseClient client, V value);

  ///
  /// Add multiple records, returns the list of generated keys.
  ///
  Future<List<K>> addAll(DatabaseClient client, List<V> values);

  /// Update records matching a given finder.
  ///
  /// Return the count updated. [value] is merged to the existing.
  Future<int> update(DatabaseClient client, V value, {Finder finder});

  /// Delete records matching a given finder.
  ///
  /// Return the count updated. Delete all if no finder
  Future<int> delete(DatabaseClient client, {Finder finder});
}

/// Store factory interface
abstract class StoreFactory<K, V> {
  StoreRef<K, V> store(String name);
}

/// common `<int, Map<String, dynamic>>` factory
final intMapStoreFactory = StoreFactoryBase<int, Map<String, dynamic>>();

/// common `<String, Map<String, dynamic>>` factory
final stringMapStoreFactory = StoreFactoryBase<String, Map<String, dynamic>>();
