import 'package:sembast/src/import_common.dart';
import 'package:sembast/src/sembast_impl.dart' show dbMainStore;
import 'package:sembast/src/store_ref_impl.dart';

/// A pointer to a store.
///
abstract class StoreRef<K extends Key, V extends Value> {
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

  /// Cast if needed
  StoreRef<RK, RV> cast<RK extends Key, RV extends Value>();
}

/// Store factory interface
abstract class StoreFactory<K extends Key, V extends Value> {
  /// Creates a reference to a store.
  StoreRef<K, V> store(String name);
}

/// Store factory with key as int and value as Map
final intMapStoreFactory = StoreFactoryBase<int, Map<String, Object?>>();

/// Store factory with key as String and value as Map
final stringMapStoreFactory = StoreFactoryBase<String, Map<String, Object?>>();
