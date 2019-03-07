import 'package:sembast/sembast.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/store/store_ref.dart';

/// A pointer to a record
abstract class RecordRef<K, V> {
  /// Store reference
  StoreRef<K, V> get store;

  /// Record key, null for new record
  K get key;

  /// Create a snapshot of a record with a given value
  RecordSnapshot<K, V> snapshot(V value);

  /// Save a record, create if needed
  Future<K> put(StoreExecutor executor, V value);

  /// get a record from the database
  Future<RecordSnapshot<K, V>> get(StoreExecutor executor);

  /// delete a record
  Future delete(StoreExecutor executor);

  /// Cast if needed
  RecordRef<RK, RV> cast<RK, RV>();
}

mixin RecordRefMixin<K, V> implements RecordRef<K, V> {
  @override
  StoreRef<K, V> store;
  @override
  K key;

  @override
  RecordSnapshot<K, V> snapshot(V value) => RecordSnapshotImpl(this, value);

  @override
  Future<K> put(StoreExecutor executor, V value) async {
    // Force
    forceReadImmutable(executor);
    return (await executor.put(value, key)) as K;
  }

  @override
  Future delete(StoreExecutor executor) {
    // Force
    forceReadImmutable(executor);
    return executor.delete(key);
  }

  @override
  Future<RecordSnapshot<K, V>> get(StoreExecutor executor) async {
    // Force
    forceReadImmutable(executor);

    var record = await executor.getRecord(key);
    if (record == null) {
      return null;
    }
    return RecordSnapshotImpl(this, record.value as V);
  }

  @override
  String toString() => 'Record(${store?.name}, $key)';

  /// Cast if needed
  @override
  RecordRef<RK, RV> cast<RK, RV>() {
    if (this is RecordRef<RK, RV>) {
      return this as RecordRef<RK, RV>;
    }
    return store.cast<RK, RV>().record(key as RK);
  }
}

class RecordRefImpl<K, V> with RecordRefMixin<K, V> {
  RecordRefImpl(StoreRef<K, V> store, K key) {
    this.store = store;
    this.key = key;
  }
}

mixin RecordSnapshotMixin<K, V> implements RecordSnapshot<K, V> {
  @override
  RecordRef<K, V> ref;

  @override
  V value;
}

/// A read record
abstract class RecordSnapshot<K, V> {
  /// Its reference
  RecordRef<K, V> get ref;

  /// The value
  V get value;
}

class RecordSnapshotImpl<K, V> with RecordSnapshotMixin<K, V> {
  RecordSnapshotImpl(RecordRef<K, V> ref, V value) {
    this.ref = ref;
    this.value = value;
  }
}
