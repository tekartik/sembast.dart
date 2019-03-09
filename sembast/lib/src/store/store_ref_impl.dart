import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/finder.dart';
import 'package:sembast/src/api/store_ref.dart';
import 'package:sembast/src/store/record_ref_impl.dart';
import 'package:sembast/src/store_executor_impl.dart';
import 'package:sembast/src/transaction_impl.dart';

class StoreRefBase<K, V> with StoreRefMixin<K, V> {
  StoreRefBase(String name) {
    this.name = name;
  }
}

mixin StoreRefMixin<K, V> implements StoreRef<K, V> {
  @override
  String name;

  @override
  RecordRef<K, V> record([K key]) {
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

  /// Add
  @override
  Future<K> add(DatabaseClient client, V value) async {
    var sembastStore = getSembastStore(client, this);
    return await sembastStore.inTransaction((txn) {
      return sembastStore
          .getSembastStore(this)
          // A null key will generate one
          .txnPut(txn as SembastTransaction, value, null);
    }) as K;
  }

  @override
  Future<RecordSnapshot<K, V>> find(DatabaseClient client,
      {Finder finder}) async {
    final sembastStore = getSembastStore(client, this);

    var record = await sembastStore.findImmutableRecord(this, finder);
    if (record == null) {
      return null;
    } else {
      return RecordSnapshotImpl<K, V>.fromRecord(record);
    }
  }

  @override
  Future<int> count(DatabaseClient client, {Filter filter}) {
    final store = getSembastStore(client, this);
    // no transaction for read
    return store.count(filter);
  }

  // Clear all
  @override
  Future clear(DatabaseClient client) {
    final store = getSembastStore(client, this);
    return store.clear();
  }

  ///
  /// Get all records from a list of keys
  ///
  @override
  Future<List<RecordSnapshot<K, V>>> getAll(
      DatabaseClient client, Iterable<K> keys) async {
    final store = getSembastStore(client, this);
    var snapshots = <RecordSnapshot<K, V>>[];
    var records = await store.getImmutableRecords(this, keys);
    await store.sembastDatabase.forEachRecords(records, (record) {
      snapshots.add(RecordSnapshotImpl<K, V>.fromRecord(record));
    });
    return snapshots;
  }

  ///
  /// return the list of deleted keys
  ///
  @override
  Future deleteAll(DatabaseClient client, Iterable keys) {
    final sembastStore = getSembastStore(client, this);
    return sembastStore.deleteAll(keys);
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
  StoreRef<K, V> store([String name]) {
    return StoreRefBase(name);
  }
}

class StoreFactoryBase<K, V> with StoreFactoryMixin<K, V> {}

/// common `<int, Map<String, dynamic>>` factory
final intMapStoreFactory = StoreFactoryBase<int, Map<String, dynamic>>();

/// common `<String, Map<String, dynamic>>` factory
final stringMapStoreFactory = StoreFactoryBase<String, Map<String, dynamic>>();

abstract class StoreClient {}
