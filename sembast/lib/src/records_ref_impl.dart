import 'dart:async';

import 'package:sembast/src/database_client_impl.dart';
import 'package:sembast/src/stream_utils.dart';

import 'import_common.dart';

/// Record ref common extension.
extension SembastRecordsRefCommonExtension<K, V> on RecordsRef<K, V> {
  /// The number of records referenced.
  int get length => keys.length;

  /// Record ref at a given index.
  RecordRef<K, V> operator [](int index) => store.record(keys[index]);

  /// Get all records references.
  List<RecordRef<K, V>> get refs =>
      keys.map((key) => store.record(key)).toList();
}

/// Record ref sembast public extension.
///
/// Provides access helper to data on the store using a given [DatabaseClient].
extension SembastRecordsRefExtension<K, V> on RecordsRef<K, V> {
  /// The number of records referenced.
  int get length => keys.length;

  /// Delete records
  Future<List<K?>> delete(DatabaseClient databaseClient) async {
    var client = getClient(databaseClient);
    return await client.inTransaction((txn) async {
      var sembastStore = client.getSembastStore(store);
      return (await sembastStore.txnDeleteAll(txn, keys)).cast<K?>();
    });
  }

  /// Get all records snapshot.
  Future<List<RecordSnapshot<K, V>?>> getSnapshots(
      DatabaseClient databaseClient) async {
    var client = getClient(databaseClient);

    return client
        .getSembastStore(store)
        .txnGetRecordSnapshots(client.sembastTransaction, this);
  }

  /// Create records that don't exist.
  ///
  /// The list of [values] must match the list of keys.
  ///
  /// Returns a list of the keys, if not inserted, a key is null.
  Future<List<K?>> add(DatabaseClient databaseClient, List<V> values) {
    if (values.length != keys.length) {
      throw ArgumentError('the list of values must match the list of keys');
    }
    var client = getClient(databaseClient);
    return client.inTransaction((txn) async {
      return await client
          .getSembastStore(store)
          .txnAddAll<K, V>(txn, values, keys);
    });
  }

  /// Save multiple records, creating the one needed.
  ///
  /// if [merge] is true and the field exists, data is merged.
  ///
  /// The list of [values] must match the list of keys.
  ///
  /// Returns the updated values.
  Future<List<V>> put(DatabaseClient databaseClient, List<V> values,
      {bool? merge}) {
    if (values.length != keys.length) {
      throw ArgumentError('the list of values must match the list of keys');
    }
    var client = getClient(databaseClient);
    return client.inTransaction((txn) async {
      return (await client
              .getSembastStore(store)
              .txnPutAll<K, V>(txn, values, keys, merge: merge))
          .cast<V>();
    });
  }

  /// Update multiple records.
  ///
  /// if value is a map, keys with dot values
  /// refer to a path in the map, unless the key is specifically escaped.
  ///
  /// The list of [values] must match the list of keys.
  ///
  /// Returns the list of updated values, a value being null if the record
  /// does not exist.
  Future<List<V?>> update(DatabaseClient databaseClient, List<V> values) {
    if (values.length != keys.length) {
      throw ArgumentError('the list of values must match the list of keys');
    }
    var client = getClient(databaseClient);
    return client.inTransaction((txn) async {
      return (await client
              .getSembastStore(store)
              .txnUpdateAll(txn, values, keys))
          .cast<V?>();
    });
  }

  /// Get all records values.
  Future<List<V?>> get(DatabaseClient client) async =>
      (await getSnapshots(client))
          .map((snapshot) => snapshot?.value)
          .toList(growable: false);

  /// Get a stream of a record snapshots from the database.
  ///
  /// It allows listening to multiple records. First emit happens when all
  /// snapshot are checked first (but can be null).
  Stream<List<RecordSnapshot<K, V>?>> onSnapshots(Database database) {
    return streamJoinAll(refs.map((e) => e.onSnapshot(database)).toList());
  }
}

/// Record ref sembast public extension.
///
/// Provides access helper to data on the store using a given [DatabaseClient].
extension SembastRecordsRefSyncExtension<K, V> on RecordsRef<K, V> {
  /// Get all records snapshot synchronously.
  List<RecordSnapshot<K, V>?> getSnapshotsSync(DatabaseClient databaseClient) {
    var client = getClient(databaseClient);

    return client
        .getSembastStore(store)
        .txnGetRecordSnapshotsSync(client.sembastTransaction, this);
  }

  /// Get all records values synchronously.
  List<V?> getSync(DatabaseClient client) => (getSnapshotsSync(client))
      .map((snapshot) => snapshot?.value)
      .toList(growable: false);

  /// Get a stream of a record snapshots from the database.
  ///
  /// It allows listening to multiple records. First emit happens synchronously all
  /// snapshot are checked first (but can be null).
  Stream<List<RecordSnapshot<K, V>?>> onSnapshotsSync(Database database) {
    return streamJoinAll(refs.map((e) => e.onSnapshotSync(database)).toList());
  }
}

/// Records ref mixin.
mixin RecordsRefMixin<K, V> implements RecordsRef<K, V> {
  @override
  late StoreRef<K, V> store;
  @override
  late List<K> keys;

  @override
  String toString() => 'Records(${store.name}, $keys)';

  /// Cast if needed
  @override
  RecordsRef<RK, RV> cast<RK extends Key?, RV extends Value?>() {
    if (this is RecordsRef<RK, RV>) {
      return this as RecordsRef<RK, RV>;
    }
    return store.cast<RK, RV>().records(keys.cast<RK>());
  }
}

/// Records ref implementation.
class SembastRecordsRef<K, V> with RecordsRefMixin<K, V> {
  /// Records ref implementation.
  SembastRecordsRef(StoreRef<K, V> store, Iterable<K> keys) {
    this.store = store;
    this.keys = keys.toList(growable: false);
  }
}
