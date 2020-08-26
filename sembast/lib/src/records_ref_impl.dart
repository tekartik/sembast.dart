import 'package:sembast/src/api/client.dart';
import 'package:sembast/src/api/record_snapshot.dart';
import 'package:sembast/src/api/records_ref.dart';
import 'package:sembast/src/api/sembast.dart';
import 'package:sembast/src/api/store_ref.dart';
import 'package:sembast/src/database_client_impl.dart';

/// Records ref mixin.
mixin RecordsRefMixin<K, V> implements RecordsRef<K, V> {
  @override
  StoreRef<K, V> store;
  @override
  List<K> keys;

  @override
  RecordRef<K, V> operator [](int index) => store.record(keys[index]);

  /// Delete records
  @override
  Future delete(DatabaseClient databaseClient) {
    var client = getClient(databaseClient);
    return client.inTransaction((txn) {
      var sembastStore = client.getSembastStore(store);
      return sembastStore.txnDeleteAll(txn, keys);
    });
  }

  /// Get record snapshots
  @override
  Future<List<RecordSnapshot<K, V>>> getSnapshots(
      DatabaseClient databaseClient) async {
    var client = getClient(databaseClient);

    return client
        .getSembastStore(store)
        .txnGetRecordSnapshots(client.sembastTransaction, this);
  }

  @override
  Future<List<K>> add(DatabaseClient databaseClient, List<V> values) {
    if (values.length != keys.length) {
      throw ArgumentError('the list of values must match the list of keys');
    }
    var client = getClient(databaseClient);
    return client.inTransaction((txn) async {
      return (await client.getSembastStore(store).txnAddAll(txn, values, keys))
          ?.cast<K>();
    });
  }

  @override
  Future<List<V>> put(DatabaseClient databaseClient, List<V> values,
      {bool merge}) {
    if (values.length != keys.length) {
      throw ArgumentError('the list of values must match the list of keys');
    }
    var client = getClient(databaseClient);
    return client.inTransaction((txn) async {
      return (await client
              .getSembastStore(store)
              .txnPutAll(txn, values, keys, merge: merge))
          ?.cast<V>();
    });
  }

  @override
  Future<List<V>> update(DatabaseClient databaseClient, List<V> values) {
    if (values.length != keys.length) {
      throw ArgumentError('the list of values must match the list of keys');
    }
    var client = getClient(databaseClient);
    return client.inTransaction((txn) async {
      return (await client
              .getSembastStore(store)
              .txnUpdateAll(txn, values, keys))
          ?.cast<V>();
    });
  }

  @override
  Future<List<V>> get(DatabaseClient client) async =>
      (await getSnapshots(client))
          .map((snapshot) => snapshot?.value)
          .toList(growable: false);

  @override
  String toString() => 'Records(${store?.name}, $keys)';

  /// Cast if needed
  @override
  RecordsRef<RK, RV> cast<RK, RV>() {
    if (this is RecordsRef<RK, RV>) {
      return this as RecordsRef<RK, RV>;
    }
    return store.cast<RK, RV>().records(keys?.cast<RK>());
  }
}

/// Records ref implementation.
class SembastRecordsRef<K, V> with RecordsRefMixin<K, V> {
  /// Records ref implementation.
  SembastRecordsRef(StoreRef<K, V> store, Iterable<K> keys) {
    if (keys == null) {
      throw ArgumentError('record keys cannot be null');
    }
    this.store = store;
    this.keys = keys.toList(growable: false);
  }
}
