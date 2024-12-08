import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/transaction_impl.dart';

import 'import_common.dart';

/// Transaction record change implementation
class SembastTransactionRecordChange<K, V> implements RecordChange<K, V> {
  @override
  final RecordSnapshot<K, V>? oldSnapshot;

  @override
  final RecordSnapshot<K, V>? newSnapshot;

  /// Transaction record change implementation.
  SembastTransactionRecordChange(this.oldSnapshot, this.newSnapshot);

  @override
  RecordChange<RK, RV> cast<RK extends Key?, RV extends Value?>() {
    if (this is RecordChange<RK, RV>) {
      return this as RecordChange<RK, RV>;
    } else {
      return SembastTransactionRecordChange(
          oldSnapshot?.cast<RK, RV>(), newSnapshot?.cast<RK, RV>());
    }
  }

  @override
  String toString() =>
      'RecordChange(${isAdd ? 'add' : (isDelete ? 'delete' : (isUpdate ? 'update' : ''))}: $oldSnapshot => $newSnapshot)';
}

/// Store change listener.
class StoreChangesListener<K, V> {
  /// The listener
  final TransactionRecordChangeListener<K, V> onChangeListener;

  /// Store change listener.
  StoreChangesListener(this.onChangeListener);

  /// Call on change
  FutureOr<void> onChange(Transaction transaction, List<RecordChange> changes) {
    return onChangeListener(
        transaction,
        changes
            .map<RecordChange<K, V>>((change) => change.cast<K, V>())
            .toList());
  }

  @override
  int get hashCode => onChangeListener.hashCode;

  @override
  bool operator ==(Object other) {
    return (other is StoreChangesListener) &&
        other.onChangeListener == onChangeListener;
  }
}

mixin _ChangeListeners {
  final _txnOldSnapshot = <RecordSnapshot?>[];
  final _txnNewSnapshot = <RecordSnapshot?>[];

  /// Clear current transaction changes.
  void txnClearChanges() {
    _txnOldSnapshot.clear();
    _txnNewSnapshot.clear();
  }

  /// Get all changes and clear its content
  List<RecordChange> getAndClearChanges() {
    var list = [
      for (var i = 0; i < _txnNewSnapshot.length; i++)
        SembastTransactionRecordChange(_txnOldSnapshot[i], _txnNewSnapshot[i])
    ];
    txnClearChanges();
    return list;
  }

  /// True if there is a pending change
  bool get hasChanges => _txnNewSnapshot.isNotEmpty;
}

// ignore: public_member_api_docs
class StoreChangesListeners with _ChangeListeners {
  // ignore: public_member_api_docs
  final onChanges = <StoreChangesListener?>[];
  // ignore: public_member_api_docs
  StoreChangesListeners();

  /// Get the record ref.
  RecordRef<Key?, Value?> getRecordRef(int index) =>
      (_txnNewSnapshot[index]?.ref ?? _txnOldSnapshot[index]?.ref)!;

  /// handle changes
  Future<void> handleChanges(SembastTransaction transaction) async {
    var changes = getAndClearChanges();
    for (var listener in onChanges) {
      var result = listener!.onChange(transaction, changes);
      if (result is Future) {
        await result;
      }
    }
  }
}

class _AllStoresChangesListener with _ChangeListeners {
  final TransactionRecordChangeListener onChanges;
  final Set<String> excludedStoreNames;

  _AllStoresChangesListener(
      {required this.onChanges, required this.excludedStoreNames});

  Future<void> handleChanges(SembastTransaction txn) async {
    var changes = getAndClearChanges();
    var result = onChanges(txn, changes);
    if (result is Future) {
      await result;
    }
  }
}

class _AllStoresChangesListeners {
  final _all = <TransactionRecordChangeListener, _AllStoresChangesListener>{};

  void addChange(RecordSnapshot<Key?, Value?>? oldSnapshot,
      RecordSnapshot<Key?, Value?>? newSnapshot) {
    for (var listener in _all.values) {
      var storeName =
          oldSnapshot?.ref.store.name ?? newSnapshot?.ref.store.name;
      if (!listener.excludedStoreNames.contains(storeName)) {
        listener._txnOldSnapshot.add(oldSnapshot);
        listener._txnNewSnapshot.add(newSnapshot);
      }
    }
  }

  void addAllStoresChangesListener(TransactionRecordChangeListener onChanges,
      {List<String>? excludedStoreNames}) {
    _all[onChanges] = _AllStoresChangesListener(
        onChanges: onChanges,
        excludedStoreNames: excludedStoreNames?.toSet() ?? {});
  }

  Iterable<_AllStoresChangesListener> get all => _all.values;
  _AllStoresChangesListeners();

  void removeListener(TransactionRecordChangeListener onChanges) {
    _all.remove(onChanges);
  }

  bool hasStoreListener(String name) {
    for (var listener in _all.values) {
      if (!listener.excludedStoreNames.contains(name)) {
        return true;
      }
    }
    return false;
  }

  Future<void> handleChanges(SembastTransaction txn) async {
    for (var listener in _all.values) {
      await listener.handleChanges(txn);
    }
  }
}

/// Database listener.
class DatabaseChangesListener {
  final _stores = <StoreRef, StoreChangesListeners>{};
  _AllStoresChangesListeners? _allStoresChangesListenersOrNull;
  _AllStoresChangesListeners get _allStoresChangesListeners =>
      _allStoresChangesListenersOrNull!;

  /// true if not empty.
  bool get isNotEmpty => !isEmpty;

  /// true if empty.
  bool get isEmpty =>
      _stores.isEmpty && _allStoresChangesListenersOrNull == null;

  /// Any pending changes?
  bool get hasStoreChanges {
    for (var listener in _stores.values) {
      if (listener.hasChanges) {
        return true;
      }
    }
    return false;
  }

  /// Any pending changes?
  bool get hasGlobalChanges {
    if (_allStoresChangesListenersOrNull == null) {
      return false;
    }
    for (var listener in _allStoresChangesListeners.all) {
      if (listener.hasChanges) {
        return true;
      }
    }
    return false;
  }

  /// Get all store changes listener
  Iterable<StoreChangesListeners> get storeChangesListeners => _stores.values;

  /// Add a given change
  void addChange(RecordSnapshot? oldSnapshot, RecordSnapshot? newSnapshot) {
    var store = oldSnapshot?.ref.store ?? newSnapshot?.ref.store;
    var storeChangesListener = _stores[store];
    if (storeChangesListener != null) {
      storeChangesListener._txnOldSnapshot.add(oldSnapshot);
      storeChangesListener._txnNewSnapshot.add(newSnapshot);
    }
    _allStoresChangesListenersOrNull?.addChange(oldSnapshot, newSnapshot);
  }

  /// True if the store has a change listener (global, store or record)
  bool storeHasChangeListener(StoreRef<Key?, Value?> ref) =>
      _hasStoreChangeListener(ref) || _hasGlobalChangeListener(ref);

  /// true if it has a change listener for this store
  bool _hasGlobalChangeListener(StoreRef<Key?, Value?> ref) =>
      _allStoresChangesListenersOrNull?.hasStoreListener(ref.name) ?? false;

  /// true if it has a change listener for this store
  bool _hasStoreChangeListener(StoreRef<Key?, Value?> ref) =>
      isNotEmpty && _stores.containsKey(ref);

  /// Clear current transaction changes.
  void txnClearChanges() {
    for (var storeChangesListener in storeChangesListeners) {
      storeChangesListener.txnClearChanges();
    }
  }

  /// Add a global change listener
  void addGlobalChangesListener(TransactionRecordChangeListener onChanges,
      {List<String>? excludedStoreNames}) {
    _allStoresChangesListenersOrNull ??= _AllStoresChangesListeners();
    _allStoresChangesListeners.addAllStoresChangesListener(onChanges,
        excludedStoreNames: excludedStoreNames);
  }

  /// Add a store change listener
  void removeGlobalChangesListener(TransactionRecordChangeListener onChanges) {
    _allStoresChangesListenersOrNull?.removeListener(onChanges);
    if (_allStoresChangesListenersOrNull?.all.isEmpty ?? true) {
      _allStoresChangesListenersOrNull = null;
    }
  }

  /// Add a store change listener
  void addStoreChangesListener<K, V>(
      StoreRef<K, V> store, TransactionRecordChangeListener<K, V> onChanges) {
    var storeChangesListeners = _stores[store];
    if (storeChangesListeners == null) {
      _stores[store] = storeChangesListeners = StoreChangesListeners();
    }
    storeChangesListeners.onChanges.add(StoreChangesListener<K, V>(onChanges));
  }

  /// Add a store change listener
  void removeStoreChangesListener<K, V>(
      StoreRef<K, V> store, TransactionRecordChangeListener<K, V> onChanges) {
    var storeChangesListeners = _stores[store];
    if (storeChangesListeners != null) {
      storeChangesListeners.onChanges
          .remove(StoreChangesListener<K, V>(onChanges));
      if (storeChangesListeners.onChanges.isEmpty) {
        _stores.remove(store);
      }
    }
  }

  /// Clear all change listener
  void close() {
    _stores.clear();
  }

  /// Handle changes
  Future<void> handleGlobalChanges(SembastTransaction txn) async {
    await _allStoresChangesListeners.handleChanges(txn);
  }
}
