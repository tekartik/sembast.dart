import 'package:sembast/src/api/client.dart';
import 'package:sembast/src/api/record_ref.dart';
import 'package:sembast/src/api/record_snapshot.dart';
import 'package:sembast/src/api/sembast.dart';
import 'package:sembast/src/api/store_ref.dart';
import 'package:sembast/src/database_client_impl.dart';
import 'package:sembast/src/record_impl.dart';

mixin RecordRefMixin<K, V> implements RecordRef<K, V> {
  @override
  StoreRef<K, V> store;
  @override
  K key;

  @override
  RecordSnapshot<K, V> snapshot(V value) => RecordSnapshotImpl(this, value);

  @override
  Future<V> update(DatabaseClient databaseClient, V value) async {
    var client = getClient(databaseClient);
    return await client.inTransaction((txn) {
      return client.getSembastStore(store).txnUpdate(txn, value, key);
    }) as V;
  }

  /// Put record
  @override
  Future<K> put(DatabaseClient databaseClient, V value, {bool merge}) async {
    var client = getClient(databaseClient);
    return await client.inTransaction((txn) {
      return client
          .getSembastStore(store)
          .txnPut(txn, value, key, merge: merge);
    }) as K;
  }

  /// Delete record
  @override
  Future delete(DatabaseClient databaseClient) {
    var client = getClient(databaseClient);
    return client.inTransaction((txn) {
      return client.getSembastStore(store).txnDelete(txn, key);
    });
  }

  /// Get record value
  @override
  Future<V> get(DatabaseClient databaseClient) async =>
      (await getSnapshot(databaseClient))?.value;

  /// Get record
  @override
  Future<RecordSnapshot<K, V>> getSnapshot(
      DatabaseClient databaseClient) async {
    var client = getClient(databaseClient);

    var record = await client
        .getSembastStore(store)
        .txnGetRecord(client.sembastTransaction, this.key);
    if (record == null) {
      return null;
    }
    return RecordSnapshotImpl<K, V>.fromRecord(record);
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
