import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/finder.dart';
import 'package:sembast/src/api/records_ref.dart';
import 'package:sembast/src/api/store_ref.dart';
import 'package:sembast/src/database_client_impl.dart';
import 'package:sembast/src/record_ref_impl.dart';
import 'package:sembast/src/record_snapshot_impl.dart';
import 'package:sembast/src/records_ref_impl.dart';

class SembastStoreRef<K, V> with StoreRefMixin<K, V> {
  SembastStoreRef(String name) {
    if (name == null) {
      throw ArgumentError(
          'Store reference name can not be null. Use StoreRef.main() to get the main store');
    }
    this.name = name;
  }
}

mixin StoreRefMixin<K, V> implements StoreRef<K, V> {
  @override
  String name;

  @override
  RecordRef<K, V> record(K key) {
    return SembastRecordRef<K, V>(this, key);
  }

  @override
  RecordsRef<K, V> records(Iterable<K> keys) {
    return SembastRecordsRef<K, V>(this, keys);
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

  /// Delete the store
  @override
  Future delete(DatabaseClient databaseClient) {
    final client = getClient(databaseClient);
    return client.inTransaction((txn) {
      return client.sembastDatabase.txnDeleteStore(txn, name);
    });
  }

  /// Add
  @override
  Future<K> add(DatabaseClient databaseClient, V value) async {
    final client = getClient(databaseClient);
    return await client.inTransaction((txn) {
      return client
          .getSembastStore(this)
          // A null key will generate one
          .txnPut(client.sembastTransaction, value, null);
    }) as K;
  }

  @override
  Future<RecordSnapshot<K, V>> findFirst(DatabaseClient databaseClient,
      {Finder finder}) async {
    final client = getClient(databaseClient);

    var record = await client
        .getSembastStore(this)
        .txnFindRecord(client.sembastTransaction, finder);
    if (record == null) {
      return null;
    } else {
      return SembastRecordSnapshot<K, V>.fromRecord(record);
    }
  }

  @override
  Future<List<RecordSnapshot<K, V>>> find(DatabaseClient databaseClient,
      {Finder finder}) async {
    final client = getClient(databaseClient);

    var records = await client
        .getSembastStore(this)
        .txnFindRecords(client.sembastTransaction, finder);
    return records
        .map((immutable) => SembastRecordSnapshot<K, V>.fromRecord(immutable))
        ?.toList(growable: false);
  }

  @override
  Future<int> count(DatabaseClient databaseClient, {Filter filter}) {
    final client = getClient(databaseClient);
    // no transaction needed for read
    return client
        .getSembastStore(this)
        .txnCount(client.sembastTransaction, filter);
  }

  // Clear all
  @override
  Future clear(DatabaseClient databaseClient) {
    final client = getClient(databaseClient);
    return client.inTransaction((txn) {
      return client.getSembastStore(this).txnClear(txn);
    });
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
    if (name == null) {
      return StoreRef<K, V>.main();
    } else {
      return StoreRef<K, V>(name);
    }
  }
}

class StoreFactoryBase<K, V> with StoreFactoryMixin<K, V> {}

/// common `<int, Map<String, dynamic>>` factory
final intMapStoreFactory = StoreFactoryBase<int, Map<String, dynamic>>();

/// common `<String, Map<String, dynamic>>` factory
final stringMapStoreFactory = StoreFactoryBase<String, Map<String, dynamic>>();

abstract class StoreClient {}
