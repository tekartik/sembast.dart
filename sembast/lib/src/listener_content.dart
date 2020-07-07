import 'package:sembast/sembast.dart';
import 'package:sembast/src/record_impl.dart';

/// Cumulated listener content.
class StoreListenerContent {
  /// Store ref.
  final StoreRef store;

  /// Record with key.
  final _map = <dynamic, ImmutableSembastRecord>{};

  /// Store listener content.
  StoreListenerContent(this.store);

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
  ImmutableSembastRecord record(key) => _map[key];

  @override
  String toString() => '${store.name} ${records.length}';
}

/// Cumulated listener content
class DatabaseListenerContent {
  final _map = <StoreRef, StoreListenerContent>{};

  /// true if at least one store.
  bool get isNotEmpty => _map.isNotEmpty;

  /// All stores.
  Iterable<StoreListenerContent> get stores => _map.values;

  /// Add a store.
  StoreListenerContent addStore(StoreRef store) {
    var storeContent = _map[store] ??= StoreListenerContent(store);
    return storeContent;
  }

  /// Add a single record.
  void addRecord(ImmutableSembastRecord record) {
    var store = record.ref.store;
    var storeContent = addStore(store);
    storeContent.add(record);
  }

  @override
  String toString() => '$stores';

  /// A given existing store.
  StoreListenerContent store(StoreRef store) => _map[store];

  /// Remove a store content
  void removeStore(StoreRef store) {
    _map.remove(store);
  }

  /// Clear listener content
  void clear() {
    _map.clear();
  }

  /// Get and remove the first store found
  StoreListenerContent getAndRemoveFirstStore() {
    if (isNotEmpty) {
      var storeContent = _map.values.first;
      _map.remove(storeContent.store);
      return storeContent;
    }
    return null;
  }
}
