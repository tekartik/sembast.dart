import 'dart:async';

import 'package:sembast/src/api/filter_ref.dart';
import 'package:sembast/src/api/protected/database.dart';
import 'package:sembast/src/database_client_impl.dart';
import 'package:sembast/src/filter_ref_impl.dart';
import 'package:sembast/src/finder_impl.dart';
import 'package:sembast/src/query_ref_impl.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/record_ref_impl.dart';
import 'package:sembast/src/record_snapshot_impl.dart';
import 'package:sembast/src/records_ref_impl.dart';
import 'package:sembast/src/sembast_impl.dart';

import 'database_impl.dart';
import 'import_common.dart';

/// Store implementation.
class SembastStoreRef<K, V> with StoreRefMixin<K, V> {
  /// Store implementation.
  SembastStoreRef(String name) {
    this.name = name;
  }

  /// Store implementation.
  SembastStoreRef.main() {
    name = dbMainStore;
  }
}

/// Store ref mixin.
mixin StoreRefMixin<K, V> implements StoreRef<K, V> {
  @override
  late String name;

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

  /// Cast if needed
  @override
  StoreRef<RK, RV> cast<RK extends Key?, RV extends Value?>() {
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
      {SembastFinder? finder}) async {
    final client = getClient(databaseClient);

    return await client
        .getSembastStore(this)
        .txnFindRecords(client.sembastTransaction, finder);
  }

  /// Find immutables records. synchronous access.
  List<ImmutableSembastRecord> findImmutableRecordsSync(
      DatabaseClient databaseClient,
      {SembastFinder? finder}) {
    final client = getClient(databaseClient);

    return client
        .getSembastStore(this)
        .txnFindRecordsSync(client.sembastTransaction, finder);
  }

  /// Find key set.
  Future<Set<K>> filterKeys(DatabaseClient databaseClient,
      {Filter? filter}) async {
    final client = getClient(databaseClient);

    return (await client
            .getSembastStore(this)
            .txnFilterKeys(client.sembastTransaction, filter))
        .cast<K>();
  }
}

/// Internal extension
extension SembastStoreRefExtensionPrv<K, V> on StoreRef<K, V> {
  /// Delete the store and its content
  FilterRef<K, V> filter({Filter? filter}) =>
      SembastFilterRef<K, V>(this as SembastStoreRef<K, V>, filter);

  /// Create a snapshot of a record with a given value.
  RecordSnapshot<K, V> snapshotFromImmutableRecord(
      ImmutableSembastRecord record) {
    return SembastRecordSnapshot<K, V>.fromRecord(this, record);
  }

  /// Create a snapshot of a record with a given value (or null).
  RecordSnapshot<K, V>? snapshotFromImmutableRecordOrNull(
          ImmutableSembastRecord? record) =>
      record == null ? null : snapshotFromImmutableRecord(record);
}

/// Store ref common public sembast extension (no db access).
extension SembastStoreRefCommonExtension<K, V> on StoreRef<K, V> {
  /// Records ref from a list of record refs.
  RecordsRef<K, V> recordsFromRefs(List<RecordRef<K, V>> refs) {
    return records(refs.map((e) => e.key).toList());
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
        .txnFindRecord(client.sembastTransaction, finder as SembastFinder?);
    if (record == null) {
      return null;
    } else {
      return SembastRecordSnapshot<K, V>.fromRecord(this, record);
    }
  }

  ///
  /// Find multiple records.
  ///
  /// Returns an empty array if none found.
  ///
  Future<List<RecordSnapshot<K, V>>> find(DatabaseClient databaseClient,
      {Finder? finder}) async {
    var records = await findImmutableRecords(databaseClient,
        finder: finder as SembastFinder?);
    return immutableListToSnapshots(records);
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
        .txnFindKey(client.sembastTransaction, finder as SembastFinder?);
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
        .txnFindKeys(client.sembastTransaction, finder as SembastFinder?);
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
  /// Soon to be Deprecated: use [query.count] instead.
  /// @Deprecated('User query(filter: filter).count instead.')
  Future<int> count(DatabaseClient databaseClient, {Filter? filter}) {
    final client = getClient(databaseClient);
    // no transaction needed for read
    return client
        .getSembastStore(this)
        .txnCount(client.sembastTransaction, filter);
  }

  ///
  /// onCount stream, called when the number of items changes.
  ///
  /// Soon to be Deprecated: use [query.onCount] instead.
  /// @Deprecated('User query(filter: filter).onCount instead.')
  Stream<int> onCount(Database database, {Filter? filter}) =>
      SembastFilterRef(this as SembastStoreRef<K, V>, filter).onCount(database);

  ///
  /// Add a record, returns its generated key.
  ///
  Future<K> add(DatabaseClient databaseClient, V value) {
    final client = getClient(databaseClient);
    value = client.sembastDatabase.sanitizeInputValue<V>(value as Value);
    return client.inTransaction<K>((txn) async {
      return (await client.getSembastStore(this).txnAdd<K>(txn, value as Value))
          as K;
    });
  }

  ///
  /// Generate a new key.
  ///
  Future<K> generateKey(DatabaseClient databaseClient) {
    final client = getClient(databaseClient);
    return client.inTransaction((txn) {
      return client.getSembastStore(this).txnGenerateUniqueKey<K>(txn);
    });
  }

  ///
  /// Generate a new int key.
  ///
  Future<int> generateIntKey(DatabaseClient databaseClient) {
    final client = getClient(databaseClient);
    return client.inTransaction((txn) {
      return client.getSembastStore(this).txnGenerateUniqueIntKey(txn);
    });
  }

  ///
  /// Add multiple records, returns the list of generated keys.
  ///
  Future<List<K>> addAll(DatabaseClient databaseClient, List<V> values) async {
    final client = getClient(databaseClient);
    var sanitizedValues = values.map((value) =>
        client.sembastDatabase.sanitizeInputValue<V>(value as Value));
    var keys = <K>[];
    await client.inTransaction((txn) async {
      var store = client.getSembastStore(this);
      for (var value in sanitizedValues) {
        keys.add((await store.txnAdd<K>(txn, value as Value)) as K);
      }
    });
    return keys;
  }

  /// Update records matching a given finder.
  ///
  /// Return the count updated. [value] is merged to the existing.
  Future<int> update(DatabaseClient databaseClient, V value, {Finder? finder}) {
    final client = getClient(databaseClient);
    value = client.sembastDatabase
        .sanitizeInputValue<V>(value as Value, update: true);
    return client.inTransaction((txn) async {
      return (await client.getSembastStore(this).txnUpdateWhere(
              txn, value as Value,
              finder: finder as SembastFinder?))
          .length;
    });
  }

  /// Delete records matching a given finder.
  ///
  /// Return the count updated. Delete all if no finder
  Future<int> delete(DatabaseClient databaseClient, {Finder? finder}) {
    final client = getClient(databaseClient);
    return client.inTransaction((txn) async {
      return (await client
              .getSembastStore(this)
              .txnClear(txn, finder: finder as SembastFinder?))
          .length;
    });
  }

  /// Listen for changes on a given store.
  ///
  /// Note that you can perform changes in the callback using the transaction
  /// provided. Also note that if you modify and already modified record,
  /// the callback will be called again.
  ///
  /// To use with caution as it has a cost.
  ///
  /// Like transaction, it can run multiple times, so limit your changes to the
  /// database.
  void addOnChangesListener(
      Database database, TransactionRecordChangeListener<K, V> onChanges) {
    (database as SembastDatabase).addOnChangesListener<K, V>(this, onChanges);
  }

  /// Stop listening for changes.
  ///
  /// Make sure the same callback is used than the one used in addOnChangesListener.
  void removeOnChangesListener(
      Database database, TransactionRecordChangeListener<K, V> onChanges) {
    (database as SembastDatabase)
        .removeOnChangesListener<K, V>(this, onChanges);
  }

  /// create snapshot list.
  List<SembastRecordSnapshot<K, V>> immutableListToSnapshots(
      List<ImmutableSembastRecord> records) {
    return records
        .map((immutable) =>
            SembastRecordSnapshot<K, V>.fromRecord(this, immutable))
        .toList(growable: false);
  }
}

/// Store ref public sembast extension.
///
/// Provides access helper to data on the store using a given [DatabaseClient].
extension SembastStoreRefSyncExtension<K, V> on StoreRef<K, V> {
  /// Find a single record.
  ///
  /// Returns null if not found.
  RecordSnapshot<K, V>? findFirstSync(DatabaseClient databaseClient,
      {Finder? finder}) {
    final client = getClient(databaseClient);

    var record = client
        .getSembastStore(this)
        .txnFindRecordSync(client.sembastTransaction, finder as SembastFinder?);
    if (record == null) {
      return null;
    } else {
      return SembastRecordSnapshot<K, V>.fromRecord(this, record);
    }
  }

  ///
  /// Find multiple records. Synchronous access.
  ///
  /// Returns an empty array if none found.
  ///
  List<RecordSnapshot<K, V>> findSync(DatabaseClient databaseClient,
      {Finder? finder}) {
    var records = findImmutableRecordsSync(databaseClient,
        finder: finder as SembastFinder?);
    return immutableListToSnapshots(records);
  }

  ///
  /// Find one key.
  ///
  /// Returns null if not found.
  ///
  K? findKeySync(DatabaseClient databaseClient, {Finder? finder}) {
    final client = getClient(databaseClient);

    var key = client
        .getSembastStore(this)
        .txnFindKeySync(client.sembastTransaction, finder as SembastFinder?);
    return (key as K?);
  }

  ///
  /// Find multiple keys.
  ///
  /// Return an empty array if none found.
  ///
  List<K> findKeysSync(DatabaseClient databaseClient, {Finder? finder}) {
    final client = getClient(databaseClient);

    var keys = client
        .getSembastStore(this)
        .txnFindKeysSync(client.sembastTransaction, finder as SembastFinder?);
    return keys.cast<K>();
  }

  ///
  /// count records.
  ///
  /// @Deprecated('Use query(filter: filter).countSync instead.')
  int countSync(DatabaseClient databaseClient, {Filter? filter}) {
    final client = getClient(databaseClient);
    // no transaction needed for read
    return client
        .getSembastStore(this)
        .txnCountSync(client.sembastTransaction, filter);
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
