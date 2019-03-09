import 'package:sembast/src/api/client.dart';
import 'package:sembast/src/api/record_ref.dart';
import 'package:sembast/src/api/record_snapshot.dart';
import 'package:sembast/src/api/sembast.dart';
import 'package:sembast/src/api/store_ref.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/store_executor_impl.dart';
import 'package:sembast/src/transaction_impl.dart';

mixin RecordRefMixin<K, V> implements RecordRef<K, V> {
  @override
  StoreRef<K, V> store;
  @override
  K key;

  @override
  RecordSnapshot<K, V> snapshot(V value) => RecordSnapshotImpl(this, value);

  @override
  Future<V> update(DatabaseClient client, V value) async {
    var sembastStore = getSembastStore(client, store);
    return await sembastStore.inTransaction((txn) {
      return sembastStore
          .getSembastStore(store)
          .txnUpdate(txn as SembastTransaction, value, key);
    }) as V;
  }

  /// Put record
  @override
  Future<K> put(DatabaseClient client, V value, {bool merge}) async {
    var sembastStore = getSembastStore(client, store);
    return await sembastStore.inTransaction((txn) {
      return sembastStore.txnPut(txn as SembastTransaction, value, key,
          merge: merge);
    }) as K;
  }

  /// Delete record
  @override
  Future delete(DatabaseClient client) {
    var sembastStore = getSembastStore(client, store);
    return sembastStore.inTransaction((txn) {
      return sembastStore
          .getSembastStore(store)
          .txnDelete(txn as SembastTransaction, key);
    });
  }

  /// Get record
  @override
  Future<RecordSnapshot<K, V>> get(DatabaseClient client) async {
    var sembastStore = getSembastStore(client, store);

    var record = await sembastStore.getImmutableRecord(this);
    if (record == null) {
      return null;
    }
    return RecordSnapshotImpl.fromRecord(record);
  }

  /// Get value
  @override
  Future<V> getValue(Database db) async => (await get(db)).value;

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

  @override
  String toString() => '$ref $value';
}

class RecordSnapshotImpl<K, V> with RecordSnapshotMixin<K, V> {
  RecordSnapshotImpl.fromRecord(ImmutableSembastRecord record) {
    this.ref = record.ref?.cast<K, V>();
    this.value = record.value as V;
  }

  RecordSnapshotImpl(RecordRef<K, V> ref, V value) {
    this.ref = ref;
    this.value = value;
  }
}
