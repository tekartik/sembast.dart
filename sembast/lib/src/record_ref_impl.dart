import 'package:sembast/src/api/client.dart';
import 'package:sembast/src/api/record_ref.dart';
import 'package:sembast/src/api/record_snapshot.dart';
import 'package:sembast/src/api/sembast.dart';
import 'package:sembast/src/api/store_ref.dart';
import 'package:sembast/src/api/v2/sembast.dart' as v2;
import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/database_client_impl.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/debug_utils.dart';
import 'package:sembast/src/listener.dart';
import 'package:sembast/src/record_snapshot_impl.dart';
import 'package:sembast/src/utils.dart';

mixin RecordRefMixin<K, V> implements RecordRef<K, V> {
  @override
  StoreRef<K, V> store;
  @override
  K key;

  @override
  RecordSnapshot<K, V> snapshot(V value) => SembastRecordSnapshot(this, value);

  /// Update record
  ///
  /// value is sanitized first
  @override
  Future<V> update(DatabaseClient databaseClient, V value) async {
    var client = getClient(databaseClient);
    value = sanitizeInputValue<V>(value);
    return await client.inTransaction((txn) {
      return client.getSembastStore(store).txnUpdate(txn, value, key);
    }) as V;
  }

  /// Put record
  ///
  /// value is sanitized first
  @override
  Future<V> put(DatabaseClient databaseClient, V value, {bool merge}) async {
    var client = getClient(databaseClient);
    value = sanitizeInputValue<V>(value);
    return await client.inTransaction((txn) {
      return client
          .getSembastStore(store)
          .txnPut(txn, value, key, merge: merge);
    }) as V;
  }

  /// Add a record
  ///
  /// value is sanitized first
  @override
  Future<K> add(DatabaseClient databaseClient, V value) async {
    var client = getClient(databaseClient);
    value = sanitizeInputValue<V>(value);
    return await client.inTransaction((txn) {
      return client.getSembastStore(store).txnAdd(txn, value, key);
    });
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
        .txnGetRecord(client.sembastTransaction, key);
    return record?.cast<K, V>();
  }

  ///
  /// Stream of record snapshot
  ///
  @override
  Stream<RecordSnapshot<K, V>> onSnapshot(v2.Database database) {
    var db = getDatabase(database);
    RecordListenerController<K, V> ctlr;
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

  @override
  Future<bool> exists(DatabaseClient databaseClient) {
    var client = getClient(databaseClient);
    return client
        .getSembastStore(store)
        .txnRecordExists(client.sembastTransaction, key);
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
