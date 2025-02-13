import 'package:sembast/src/record_impl.dart';

import 'import_common.dart';

/// Store content.
class StoreContent {
  /// Store ref.
  final StoreRef<Key?, Value?> store;

  /// Record with key.
  final _map = <Object?, ImmutableSembastRecord>{};

  /// Store content.
  StoreContent(this.store);

  /// All records.
  Iterable<ImmutableSembastRecord> get records => _map.values;

  /// Add all records.
  void addAll(Iterable<ImmutableSembastRecord> records) {
    for (var record in records) {
      add(record);
    }
  }

  /// Add a single record.
  void add(ImmutableSembastRecord record) {
    _map[record.key] = record;
  }

  /// Get a single record.
  ImmutableSembastRecord? record(Object key) => _map[key];

  @override
  String toString() => '${store.name} ${records.length}';
}

/// Database content.
///
/// Use for listener and transaction
class DatabaseContent {
  final _map = <StoreRef, StoreContent>{};

  /// true if at least one store.
  bool get isNotEmpty => _map.isNotEmpty;

  /// All stores.
  Iterable<StoreContent> get stores => _map.values;

  /// Add all records.
  void addAll(Iterable<ImmutableSembastRecord> records) {
    for (var record in records) {
      addRecord(record);
    }
  }

  /// Add a single record.
  void addRecord(ImmutableSembastRecord record) {
    var store = record.ref.store;
    var content = addStore(store);
    content.add(record);
  }

  /// Add a store.
  StoreContent addStore(StoreRef<Key?, Value?> store) {
    var content = _map[store] ??= StoreContent(store);
    return content;
  }

  /// A given existing store.
  StoreContent? store(StoreRef<Key?, Value?> store) => _map[store];

  @override
  String toString() => '$stores';
}

/// Cumulated listener content
class DatabaseListenerContent extends DatabaseContent {
  /// Remove a store content
  void removeStore(StoreRef<Key?, Value?> store) {
    _map.remove(store);
  }

  /// Clear listener content
  void clear() {
    _map.clear();
  }

  /// Get and remove the first store found
  StoreContent? getAndRemoveFirstStore() {
    if (isNotEmpty) {
      var storeContent = _map.values.first;
      _map.remove(storeContent.store);
      return storeContent;
    }
    return null;
  }
}

/// Database content in a transaction.
class TxnDatabaseContent extends DatabaseContent {
  final _records = <TxnRecord>[];

  /// All transaction records
  List<TxnRecord> get txnRecords => _records;

  /// Add a transaction record.
  void addTxnRecord(TxnRecord record) {
    _records.add(record);
    addRecord(record.record);
  }

  /// Add transaction records for a give store
  void addTxnStoreRecords(
    StoreRef<Key?, Value?> store,
    Iterable<TxnRecord> records,
  ) {
    addStore(store).addAll(records.map((record) => record.record));
    _records.addAll(records);
  }
}
