import 'package:sembast/sembast.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/store/record_ref.dart';

class StoreRefBase<K, V> with StoreRefMixin<K, V> {
  StoreRefBase(String name) {
    this.name = name;
  }
}

mixin StoreRefMixin<K, V> implements StoreRef<K, V> {
  @override
  String name;

  @override
  RecordRef<K, V> record(K key) {
    return RecordRefImpl<K, V>(this, key);
  }

  @override
  String toString() => 'Store($name)';

  @override
  int get hashCode => name.hashCode;

  @override
  bool operator ==(other) {
    if (other is StoreRef) {
      return other.name == name;
    }
    return false;
  }

  Future<RecordSnapshot<K, V>> findRecord(
      StoreExecutor executor, Finder finder) async {
    // Force immutable as soon as we use such api
    forceReadImmutable(executor);

    var record = await executor.findRecord(finder);
    if (record == null) {
      return null;
    } else {
      return RecordSnapshotImpl<K, V>(
          record.ref?.cast<K, V>(), record.value as V);
    }
  }

  /// Cast if needed
  @override
  StoreRef<RK, RV> cast<RK, RV>() {
    if (this is StoreRef<RK, RV>) {
      return this as StoreRef<RK, RV>;
    }
    return StoreRef<RK, RV>(name);
  }
}

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

mixin StoreFactoryMixin<K, V> implements StoreFactory<K, V> {
  @override
  StoreRef<K, V> store(String name) {
    return StoreRefBase(name);
  }
}

class StoreFactoryBase<K, V> with StoreFactoryMixin<K, V> {}

/// common `<int, Map<String, dynamic>>` factory
final intMapStoreFactory = StoreFactoryBase<int, Map<String, dynamic>>();

/// common `<String, Map<String, dynamic>>` factory
final stringMapStoreFactory = StoreFactoryBase<String, Map<String, dynamic>>();
