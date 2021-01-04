import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/finder.dart';
import 'package:sembast/src/api/query_ref.dart';
import 'package:sembast/src/api/records_ref.dart';
import 'package:sembast/src/api/store_ref.dart';
import 'package:sembast/src/database_client_impl.dart';
import 'package:sembast/src/finder_impl.dart';
import 'package:sembast/src/query_ref_impl.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/record_ref_impl.dart';
import 'package:sembast/src/record_snapshot_impl.dart';
import 'package:sembast/src/records_ref_impl.dart';

/// Store implementation.
class SembastStoreRef<K, V> with StoreRefMixin<K, V> {
  /// Store implementation.
  SembastStoreRef(String name) {
    this.name = name;
  }
}

/// Store ref mixin.
mixin StoreRefMixin<K, V> implements StoreRef<K, V> {
  @override
  late String name;

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

  /// Cast if needed
  @override
  StoreRef<RK, RV> cast<RK, RV>() {
    if (this is StoreRef<RK, RV>) {
      return this as StoreRef<RK, RV>;
    }
    return StoreRef<RK, RV>(name);
  }
}

/// Store ref private sembast extension.
extension SembastStoreRefExtensionImpl<K, V> on StoreRef<K, V> {
  /// Find immutables records.
  Future<List<ImmutableSembastRecord>> findImmutableRecords(
      DatabaseClient databaseClient,
      {Finder? finder}) async {
    final client = getClient(databaseClient);

    return await client
        .getSembastStore(this)
        .txnFindRecords(client.sembastTransaction, finder);
  }
}

/// Store ref public sembast extension.
///
/// Provides access helper to data on the store using a given [DatabaseClient].
extension SembastStoreRefExtension<K, V> on StoreRef<K, V> {
  /// Delete the store and its content
  Future drop(DatabaseClient databaseClient) {
    final client = getClient(databaseClient);
    return client.inTransaction((txn) {
      return client.sembastDatabase.txnDeleteStore(txn, name);
    });
  }

  /// Find a single record.
  ///
  /// Returns null if not found.
  Future<RecordSnapshot<K, V>?> findFirst(DatabaseClient databaseClient,
      {Finder? finder}) async {
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

  ///
  /// Find multiple records.
  ///
  /// Returns an empty array if none found.
  ///
  Future<List<RecordSnapshot<K, V>>> find(DatabaseClient databaseClient,
      {Finder? finder}) async {
    var records = await findImmutableRecords(databaseClient, finder: finder);
    return immutableListToSnapshots<K, V>(records);
  }

  ///
  /// Create a query with a finder.
  ///
  QueryRef<K, V> query({Finder? finder}) {
    return SembastQueryRef(this, finder as SembastFinder?);
  }

  ///
  /// Find one key.
  ///
  /// Returns null if not found.
  ///
  Future<K?> findKey(DatabaseClient databaseClient, {Finder? finder}) async {
    final client = getClient(databaseClient);

    var key = await client
        .getSembastStore(this)
        .txnFindKey(client.sembastTransaction, finder);
    return (key as K?);
  }

  ///
  /// Find multiple keys.
  ///
  /// Return an empty array if none found.
  ///
  Future<List<K>> findKeys(DatabaseClient databaseClient,
      {Finder? finder}) async {
    final client = getClient(databaseClient);

    var keys = await client
        .getSembastStore(this)
        .txnFindKeys(client.sembastTransaction, finder);
    return keys.cast<K>();
  }

  /// Unsorted record stream
  Stream<RecordSnapshot<K, V>> stream(DatabaseClient databaseClient,
      {Filter? filter}) {
    final client = getClient(databaseClient);

    return client
        .getSembastStore(this)
        .txnGetStream(client.sembastTransaction, filter);
  }

  ///
  /// count records.
  ///
  Future<int> count(DatabaseClient databaseClient, {Filter? filter}) {
    final client = getClient(databaseClient);
    // no transaction needed for read
    return client
        .getSembastStore(this)
        .txnCount(client.sembastTransaction, filter);
  }

  ///
  /// Add a record, returns its generated key.
  ///
  Future<K> add(DatabaseClient databaseClient, V value) async {
    final client = getClient(databaseClient);
    value = client.sembastDatabase.sanitizeInputValue<V>(value)!;
    return await client.inTransaction((txn) async {
      var key = await client
          .getSembastStore(this)
          .txnAdd<K, V>(client.sembastTransaction, value);
      return key as K;
    });
  }

  ///
  /// Add multiple records, returns the list of generated keys.
  ///
  Future<List<K>> addAll(DatabaseClient databaseClient, List<V> values) async {
    final client = getClient(databaseClient);
    var sanitizedValues = values
        .map((value) => client.sembastDatabase.sanitizeInputValue<V>(value));
    var keys = <K>[];
    await client.inTransaction((txn) async {
      var store = client.getSembastStore(this);
      for (var value in sanitizedValues) {
        keys.add((await store.txnAdd<K, V>(client.sembastTransaction, value))!);
      }
    });
    return keys;
  }

  /// Update records matching a given finder.
  ///
  /// Return the count updated. [value] is merged to the existing.
  Future<int> update(DatabaseClient databaseClient, V value, {Finder? finder}) {
    final client = getClient(databaseClient);
    value = client.sembastDatabase.sanitizeInputValue<V>(value, update: true)!;
    return client.inTransaction((txn) async {
      return (await client
              .getSembastStore(this)
              .txnUpdateWhere(txn, value, finder: finder))
          .length;
    });
  }

  /// Delete records matching a given finder.
  ///
  /// Return the count updated. Delete all if no finder
  Future<int> delete(DatabaseClient databaseClient, {Finder? finder}) {
    final client = getClient(databaseClient);
    return client.inTransaction((txn) async {
      return (await client.getSembastStore(this).txnClear(txn, finder: finder))
          .length;
    });
  }
}

/// Store factory mixin.
mixin StoreFactoryMixin<K, V> implements StoreFactory<K, V> {
  @override
  StoreRef<K, V> store([String? name]) {
    if (name == null) {
      return StoreRef<K, V>.main();
    } else {
      return StoreRef<K, V>(name);
    }
  }
}

/// Store factory base.
class StoreFactoryBase<K, V> with StoreFactoryMixin<K, V> {}

/// common `<int, Map<String, Object?>>` factory
final intMapStoreFactory = StoreFactoryBase<int, Map<String, Object?>>();

/// common `<String, Map<String, Object?>>` factory
final stringMapStoreFactory = StoreFactoryBase<String, Map<String, Object?>>();
