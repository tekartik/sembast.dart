import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_store.dart';
import 'package:sembast/src/store/record_ref.dart';
import 'package:sembast/src/store/record_ref_impl.dart';
import 'package:sembast/src/store/store_ref.dart';
import 'package:sembast/src/store_executor_impl.dart';

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

  @override
  Future<RecordSnapshot<K, V>> find(
      DatabaseClient client, Finder finder) async {
    final storeExecutor = storeExecutorMixin(client);

    var record = await storeExecutor.findImmutableRecord(this, finder);
    if (record == null) {
      return null;
    } else {
      return RecordSnapshotImpl<K, V>.fromRecord(record);
    }
  }

  // Clear all
  @override
  Future clear(DatabaseClient client) {
    final storeExecutor = storeExecutorMixin(client);
    return storeExecutor.clear();
  }

  ///
  /// Get all records from a list of keys
  ///
  @override
  Future<List<RecordSnapshot<K, V>>> getAll(
      DatabaseClient client, Iterable<K> keys) async {
    final storeExecutor = storeExecutorMixin(client);
    var snapshots = <RecordSnapshot<K, V>>[];
    var records = await storeExecutor.getImmutableRecords(this, keys);
    await storeExecutor.sembastDatabase.forEachRecords(records, (record) {
      snapshots.add(RecordSnapshotImpl<K, V>.fromRecord(record));
    });
    return snapshots;
  }

  ///
  /// return the list of deleted keys
  ///
  @override
  Future deleteAll(DatabaseClient client, Iterable keys) {
    final storeExecutor = storeExecutorMixin(client);
    return storeExecutor.deleteAll(keys);
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

abstract class StoreClient {}
