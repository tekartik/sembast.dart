import 'package:sembast/sembast_store.dart';
import 'package:sembast/src/store/record_ref.dart';
import 'package:sembast/src/store/store_ref.dart';
import 'package:sembast/src/store_executor_impl.dart';
import 'package:sembast/src/transaction_impl.dart';
import 'package:sembast/src/utils.dart';

mixin RecordRefMixin<K, V> implements RecordRef<K, V> {
  @override
  StoreRef<K, V> store;
  @override
  K key;

  @override
  RecordSnapshot<K, V> snapshot(V value) => RecordSnapshotImpl(this, value);

  @override
  Future<K> put(DatabaseClient client, V value, {bool merge}) async {
    var executorMixin = storeExecutorMixin(client);
    return await executorMixin.inTransaction((txn) {
      return executorMixin.sembastStore
          .txnPut(txn as SembastTransaction, value, key, merge: merge);
    }) as K;
  }

  @override
  Future delete(DatabaseClient client) {
    var executorMixin = storeExecutorMixin(client);
    return executorMixin.delete(key);
  }

  @override
  Future<RecordSnapshot<K, V>> get(DatabaseClient client) async {
    var executorMixin = storeExecutorMixin(client);

    var record = await executorMixin.getRecord(key);
    if (record == null) {
      return null;
    }
    return RecordSnapshotImpl(this, immutableValue(record.value) as V);
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

class RecordSnapshotImpl<K, V> with RecordSnapshotMixin<K, V> {
  RecordSnapshotImpl(RecordRef<K, V> ref, V value) {
    this.ref = ref;
    this.value = value;
  }
}
