import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/finder.dart';
import 'package:sembast/src/api/query_ref.dart';
import 'package:sembast/src/api/records_ref.dart';
import 'package:sembast/src/api/store_ref.dart';
import 'package:sembast/src/database_client_impl.dart';
import 'package:sembast/src/query_ref_impl.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/record_ref_impl.dart';
import 'package:sembast/src/record_snapshot_impl.dart';
import 'package:sembast/src/records_ref_impl.dart';
import 'package:sembast/src/utils.dart';
import 'package:sembast/src/api/compat/sembast.dart';
// ignore_for_file: deprecated_member_use_from_same_package

/// Store implementation.
class SembastStoreRef<K, V> with StoreRefMixin<K, V> {
  /// Store implementation.
  SembastStoreRef(String name) {
    if (name == null) {
      throw ArgumentError(
          'Store reference name cannot be null. Use StoreRef.main() to get the main store');
    }
    this.name = name;
  }
}

mixin StoreRefMixin<K, V> implements StoreRef<K, V> {
  @override
  String name;

  @override
  RecordRef<K, V> record(K key) {
    if (key == null) {
      throw ArgumentError('Record key cannot be null');
    }
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
  Future drop(DatabaseClient databaseClient) {
    final client = getClient(databaseClient);
    return client.inTransaction((txn) {
      return client.sembastDatabase.txnDeleteStore(txn, name);
    });
  }

  /// Add
  @override
  Future<K> add(DatabaseClient databaseClient, V value) async {
    final client = getClient(databaseClient);
    value = sanitizeInputValue<V>(value);
    return await client.inTransaction((txn) {
      return client
          .getSembastStore(this)
          .txnAdd<K, V>(client.sembastTransaction, value);
    });
  }

  /// Add all
  @override
  Future<List<K>> addAll(DatabaseClient databaseClient, List<V> values) async {
    final client = getClient(databaseClient);
    var sanitizedValues = values.map((value) => sanitizeInputValue<V>(value));
    var keys = <K>[];
    await client.inTransaction((txn) async {
      var store = client.getSembastStore(this);
      for (var value in sanitizedValues) {
        keys.add(await store.txnAdd<K, V>(client.sembastTransaction, value));
      }
    });
    return keys;
  }

  /// Find first record
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

  /// Find immutables records.
  Future<List<ImmutableSembastRecord>> findImmutableRecords(
      DatabaseClient databaseClient,
      {Finder finder}) async {
    final client = getClient(databaseClient);

    return await client
        .getSembastStore(this)
        .txnFindRecords(client.sembastTransaction, finder);
  }

  /// Find records
  @override
  Future<List<RecordSnapshot<K, V>>> find(DatabaseClient databaseClient,
      {Finder finder}) async {
    var records = await findImmutableRecords(databaseClient, finder: finder);
    return immutableListToSnapshots<K, V>(records);
  }

  /// Find first key
  @override
  Future<K> findKey(DatabaseClient databaseClient, {Finder finder}) async {
    final client = getClient(databaseClient);

    var key = await client
        .getSembastStore(this)
        .txnFindKey(client.sembastTransaction, finder);
    return key as K;
  }

  @override
  Future<List<K>> findKeys(DatabaseClient databaseClient,
      {Finder finder}) async {
    final client = getClient(databaseClient);

    var keys = await client
        .getSembastStore(this)
        .txnFindKeys(client.sembastTransaction, finder);
    return keys.cast<K>();
  }

  // find as stream
  @override
  Stream<RecordSnapshot<K, V>> stream(DatabaseClient databaseClient,
      {Filter filter}) {
    final client = getClient(databaseClient);

    return client
        .getSembastStore(this)
        .txnGetStream(client.sembastTransaction, filter);
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
  Future<int> delete(DatabaseClient databaseClient, {Finder finder}) {
    final client = getClient(databaseClient);
    return client.inTransaction((txn) async {
      return (await client.getSembastStore(this).txnClear(txn, finder: finder))
          .length;
    });
  }

  /// Value is sanitized first
  @override
  Future<int> update(DatabaseClient databaseClient, V value, {Finder finder}) {
    final client = getClient(databaseClient);
    value = sanitizeInputValue<V>(value);
    return client.inTransaction((txn) async {
      return (await client
              .getSembastStore(this)
              .txnUpdateWhere(txn, value, finder: finder))
          .length;
    });
  }

  @override
  QueryRef<K, V> query({Finder finder}) {
    return SembastQueryRef(this, finder as SembastFinder);
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

/// Store factory base.
class StoreFactoryBase<K, V> with StoreFactoryMixin<K, V> {}

/// common `<int, Map<String, dynamic>>` factory
final intMapStoreFactory = StoreFactoryBase<int, Map<String, dynamic>>();

/// common `<String, Map<String, dynamic>>` factory
final stringMapStoreFactory = StoreFactoryBase<String, Map<String, dynamic>>();

// Deprecated since 2019-10-28, never used before.
/// Deprecated.
@deprecated
abstract class StoreClient {}
