import 'package:sembast/src/api/sembast.dart';
import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/database_client_impl.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/debug_utils.dart';
import 'package:sembast/src/listener.dart';
import 'package:sembast/src/record_snapshot_impl.dart';

/// Record ref mixin.
mixin RecordRefMixin<K, V> implements RecordRef<K, V> {
  @override
  late StoreRef<K, V> store;
  @override
  late K key;

  @override
  String toString() => 'Record(${store.name}, $key)';

  /// Cast if needed
  @override
  RecordRef<RK, RV> cast<RK, RV>() {
    if (this is RecordRef<RK, RV>) {
      return this as RecordRef<RK, RV>;
    }
    return store.cast<RK, RV>().record(key as RK);
  }

  @override
  int get hashCode => key.hashCode;

  @override
  bool operator ==(other) {
    if (other is RecordRef) {
      return other.store == store && other.key == key;
    }
    return false;
  }
}

/// Record ref implementation.
class SembastRecordRef<K, V> with RecordRefMixin<K, V> {
  /// Record ref implementation.
  SembastRecordRef(StoreRef<K, V> store, K key) {
    this.store = store;
    this.key = key;
  }
}

/// Record ref sembast public extension.
///
/// Provides access helper to data on the store using a given [DatabaseClient].
extension SembastRecordRefExtension<K, V> on RecordRef<K, V> {
  /// Create a snapshot of a record with a given value.
  RecordSnapshot<K, V> snapshot(V value) => SembastRecordSnapshot(this, value);

  /// Create the record if it does not exist.
  ///
  /// Returns the key if inserted, null otherwise.
  Future<K?> add(DatabaseClient databaseClient, V value) async {
    var client = getClient(databaseClient);
    value = client.sembastDatabase.sanitizeInputValue<V>(value)!;
    return await client.inTransaction((txn) {
      return client.getSembastStore(store).txnAdd<K, V>(txn, value, key);
    });
  }

  /// Save a record, create if needed.
  ///
  /// if [merge] is true and the field exists, data is merged
  ///
  /// Returns the updated value.
  Future<V> put(DatabaseClient databaseClient, V value, {bool? merge}) async {
    var client = getClient(databaseClient);
    value = client.sembastDatabase.sanitizeInputValue<V>(value, update: merge)!;
    return (await client.inTransaction((txn) {
      return client
          .getSembastStore(store)
          .txnPut(txn, value, key, merge: merge);
    }) as V?)!;
  }

  /// Update a record.
  ///
  /// If it does not exist, return null. if value is a map, keys with dot values
  /// refer to a path in the map, unless the key is specifically escaped
  ///
  /// Returns the updated value.
  Future<V?> update(DatabaseClient databaseClient, V value) async {
    var client = getClient(databaseClient);
    value = client.sembastDatabase.sanitizeInputValue<V>(value, update: true)!;
    return await client.inTransaction((txn) {
      return client.getSembastStore(store).txnUpdate(txn, value, key);
    }) as V?;
  }

  /// Get a record value from the database.
  Future<V?> get(DatabaseClient databaseClient) async =>
      (await getSnapshot(databaseClient))?.value;

  /// Get a record snapshot from the database.
  Future<RecordSnapshot<K, V>?> getSnapshot(
      DatabaseClient databaseClient) async {
    var client = getClient(databaseClient);

    var record = await client
        .getSembastStore(store)
        .txnGetRecord(client.sembastTransaction, key);
    return record?.cast<K, V>();
  }

  /// Get a stream of a record snapshot from the database.
  ///
  /// It allows listening to a single instance of a record.
  Stream<RecordSnapshot<K, V>?> onSnapshot(Database database) {
    var db = getDatabase(database);
    late RecordListenerController<K, V> ctlr;
    ctlr = db.listener.addRecord(this, onListen: () {
      // Read right away
      () async {
        await db.notificationLock.synchronized(() async {
          // Don't crash here, the database might have been closed
          try {
            // Add the existing snapshot
            var snapshot = await getSnapshot(database);
            if (debugListener) {
              print('matching $ctlr: $snapshot on $this');
            }
            ctlr.add(snapshot);
          } catch (error, stackTrace) {
            ctlr.addError(error, stackTrace);
          }
        });
      }();
    });
    return ctlr.stream;
  }

  /// Return true if the record exists.
  Future<bool> exists(DatabaseClient databaseClient) {
    var client = getClient(databaseClient);
    return client
        .getSembastStore(store)
        .txnRecordExists(client.sembastTransaction, key);
  }

  /// Delete the record. Returns the key if deleted, null if not found.
  Future<K?> delete(DatabaseClient databaseClient) {
    var client = getClient(databaseClient);
    return client.inTransaction((txn) async {
      return await client.getSembastStore(store).txnDelete(txn, key) as K?;
    });
  }
}
