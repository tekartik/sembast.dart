import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/finder.dart';
import 'package:sembast/src/api/store_ref.dart';
import 'package:sembast/src/database_client_impl.dart';
import 'package:sembast/src/store/record_ref_impl.dart';

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
  Future<RecordSnapshot<K, V>> find(DatabaseClient databaseClient,
      {Finder finder}) async {
    final client = getClient(databaseClient);

    var record = await client
        .getSembastStore(this)
        .txnFindRecord(client.sembastTransaction, finder);
    if (record == null) {
      return null;
    } else {
      return RecordSnapshotImpl<K, V>.fromRecord(record);
    }
  }

  @override
  Future<int> count(DatabaseClient databaseClient, {Filter filter}) {
    final client = getClient(databaseClient);
    // no transaction needed for read
    return client.getSembastStore(this).count(filter);
  }

  // Clear all
  @override
  Future clear(DatabaseClient databaseClient) {
    final client = getClient(databaseClient);
    return client.inTransaction((txn) {
      return client.getSembastStore(this).txnClear(txn);
    });
  }

  ///
  /// Get all records from a list of keys
  ///
  @override
  Future<List<RecordSnapshot<K, V>>> getAll(
      DatabaseClient databaseClient, Iterable<K> keys) async {
    final client = getClient(databaseClient);
    var snapshots = <RecordSnapshot<K, V>>[];
    var records = await client
        .getSembastStore(this)
        .txnGetRecords(client.sembastTransaction, keys);
    await client.sembastDatabase.forEachRecords(records, (record) {
      snapshots.add(RecordSnapshotImpl<K, V>.fromRecord(record));
    });
    return snapshots;
  }

  ///
  /// return the list of deleted keys
  ///
  @override
  Future<List<K>> deleteAll(DatabaseClient databaseClient, Iterable<K> keys) {
    final client = getClient(databaseClient);
    return client.inTransaction((txn) async {
      return (await client.getSembastStore(this).txnClear(txn))?.cast<K>();
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
    return StoreRefBase(name);
  }
}

class StoreFactoryBase<K, V> with StoreFactoryMixin<K, V> {}

/// common `<int, Map<String, dynamic>>` factory
final intMapStoreFactory = StoreFactoryBase<int, Map<String, dynamic>>();

/// common `<String, Map<String, dynamic>>` factory
final stringMapStoreFactory = StoreFactoryBase<String, Map<String, dynamic>>();

abstract class StoreClient {}
