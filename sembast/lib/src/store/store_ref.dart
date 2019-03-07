import 'package:sembast/src/store/record_ref.dart';
import 'package:sembast/src/store/store_ref_impl.dart';

/// A pointer to a store
abstract class StoreRef<K, V> {
  /// The name of the store
  String get name;

  /// Create a record reference
  RecordRef<K, V> record(K key);

  factory StoreRef(String name) => StoreRefBase(name);

  /// Cast if needed
  StoreRef<RK, RV> cast<RK, RV>();
}

//
abstract class StoreFactory<K, V> {
  StoreRef<K, V> store(String name);
}

/// common `<int, Map<String, dynamic>>` factory
final intMapStoreFactory = StoreFactoryBase<int, Map<String, dynamic>>();

/// common `<String, Map<String, dynamic>>` factory
final stringMapStoreFactory = StoreFactoryBase<String, Map<String, dynamic>>();
