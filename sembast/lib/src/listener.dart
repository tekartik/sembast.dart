import 'package:meta/meta.dart';
import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/cooperator.dart';
import 'package:sembast/src/debug_utils.dart';
import 'package:sembast/src/filter_impl.dart';
import 'package:sembast/src/finder_impl.dart';
import 'package:sembast/src/query_ref_impl.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/sort.dart';
import 'package:sembast/src/store_ref_impl.dart';
import 'package:sembast/src/utils.dart';
import 'package:synchronized/synchronized.dart';

import 'api/filter_ref.dart';
import 'filter_ref_impl.dart';
import 'import_common.dart';

class _ControllerBase<T> {
  late StreamController<T> _streamController;

  /// onListen to start or restart query.
  void Function()? onListen;

  /// true if closed.
  bool get isClosed => _streamController.isClosed;

  bool get _shouldAdd => !isClosed && _streamController.hasListener;

  /// stream.
  Stream<T> get stream => _streamController.stream;

  /// Restart controller.
  void restart() {
    if (_shouldAdd) {
      if (debugListener) {
        // ignore: avoid_print
        print('restarting listener $this');
      }
      onListen!();
    }
  }

  /// close controller.

  @mustCallSuper
  void close() {
    _streamController.close();
  }

  /// Lock
  final lock = Lock();

  static var _lastId = 0;

  /// Debug only
  int? _id;

  /// The stream controller.
  _ControllerBase({required this.onListen}) {
    _id = ++_lastId;
  }

  /// Add error.
  void addError(Object error, StackTrace stackTrace) {
    if (!_shouldAdd) {
      return;
    }
    _streamController.addError(error, stackTrace);
  }
}

/// Query, QueryKeys or Count base listener.
abstract class StoreListenerController<K, V> {
  /// The lock
  Lock get lock;

  /// Store reference.
  StoreRef<K, V> get storeRef;

  /// True if the initial data has been filled.
  bool get hasInitialData;

  /// Restart.
  void restart();

  /// Close.
  void close();

  /// Update the query with the updated records (including deleted)
  Future update(
      Iterable<ImmutableSembastRecord> records, Cooperator? cooperator);

  /// Add an error
  void addError(Object error, StackTrace stackTrace);
}

/// Query or Count base listener.
abstract class _StoreListenerControllerBase<K, V, T> extends _ControllerBase<T>
    implements StoreListenerController<K, V> {
  List<ImmutableSembastRecord>? _allMatching;

  /// True when the first data has arrived
  @override
  bool get hasInitialData => _allMatching != null;

  /// Base store listener
  _StoreListenerControllerBase(DatabaseListener listener,
      {required super.onListen}) {
    // devPrint('query $queryRef');

    _streamController = StreamController<T>(onCancel: () {
      // Auto remove
      if (debugListener) {
        // ignore: avoid_print
        print('onCancel $this');
      }
      listener.removeStore(this);
      close();
    }, onListen: () {
      if (debugListener) {
        // ignore: avoid_print
        print('onListen $this');
      }
      onListen!();
    });
  }
}

/// Query/Count key listener controller.
class QueryKeysListenerController<K, V>
    extends _QueryRecordsListenerControllerBase<K, V, List<K>> {
  /// Query keys listener controller.
  QueryKeysListenerController(super.listener,
      {required super.onListen, required super.queryRef});

  @override
  void addRecords(List<ImmutableSembastRecord> list) {
    _streamController
        .add(storeRef.immutableRecordIterableToKeys(list).toList());
  }
}

/// Interface for query records listener controller (for keys or snapshots).
abstract class QueryRecordsListenerController<K, V>
    implements StoreListenerController<K, V> {
  /// Add a list of mathching records
  Future add(List<ImmutableSembastRecord>? allMatching, Cooperator? cooperator);
}

abstract class _QueryRecordsListenerControllerBase<K, V, T>
    extends _StoreListenerControllerBase<K, V, T>
    implements QueryRecordsListenerController<K, V> {
  /// The current list
  List<T>? list;

  @override
  StoreRef<K, V> get storeRef => queryRef.store;

  /// Keys or Snapshot handling
  void addRecords(List<ImmutableSembastRecord> list);

  /// The query.
  final SembastQueryRef<K, V> queryRef;

  /// Query records listener controller.
  _QueryRecordsListenerControllerBase(super.listener,
      {required super.onListen, required this.queryRef});

  /// The finder.
  // ignore: deprecated_member_use_from_same_package
  SembastFinder? get finder => queryRef.finder;

  /// Add data to stream, allMatching is already sorted, lock must have been acquired.
  @override
  Future add(
      List<ImmutableSembastRecord>? allMatching, Cooperator? cooperator) async {
    assert(lock.inLock);
    // Filter only
    _allMatching = allMatching;

    if (!_shouldAdd) {
      return;
    }

    var list = recordsLimit(_allMatching, finder);

    addRecords(list!);
  }

  /// Update the records.
  ///
  /// We are async safe here
  @override
  Future update(
      Iterable<ImmutableSembastRecord> records, Cooperator? cooperator) async {
    if (!_shouldAdd) {
      return;
    }

    // This ensure _allMatching is not null
    await lock.synchronized(() async {
      var hasChanges = false;

      // Restart from the base we have for efficiency
      var allMatching = List<ImmutableSembastRecord>.from(_allMatching!);

      var keys = Set<Object?>.from(records.map((record) => record.key));
      // Remove all matching
      bool whereSnapshot(RecordSnapshot snapshot) {
        if (keys.contains(snapshot.key)) {
          hasChanges = true;
          return true;
        }
        return false;
      }

      // Remove and reinsert if needed
      allMatching.removeWhere(whereSnapshot);

      for (var txnRecord in records) {
        // By default matches if non-deleted
        var matches = !txnRecord.deleted &&
            // Matching boundaries
            finderMatchesFilterAndBoundaries(finder, txnRecord);

        if (matches) {
          hasChanges = true;
          // insert at the proper location
          allMatching.insert(
              findSortedIndex(allMatching, txnRecord,
                  finder?.compareThenKey ?? compareRecordKey),
              txnRecord);
        }

        if (cooperator?.needCooperate ?? false) {
          await cooperator!.cooperate();
        }

        if (isClosed) {
          return;
        }
      }
      if (hasChanges) {
        await add(allMatching, cooperator);
      }
    });
  }
}

/// Query listener controller.
class QueryListenerController<K, V> extends _QueryRecordsListenerControllerBase<
    K, V, List<RecordSnapshot<K, V>>> {
  /// The filter.
  SembastFilterBase? get filter => finder?.filter as SembastFilterBase?;

  /// Query listener controller.
  QueryListenerController(super.listener,
      {required super.queryRef, required super.onListen});

  @override
  void addRecords(List<ImmutableSembastRecord> list) {
    _streamController
        .add(storeRef.immutableRecordIterableToSnapshots(list).toList());
  }

  @override
  String toString() => 'QueryListenerCtlr($_id)';
}

/// Record listener controller.
class RecordListenerController<K, V>
    extends _ControllerBase<RecordSnapshot<K, V>?> {
  /// The record ref.
  final RecordRef<K, V> recordRef;

  /// has initial data.
  bool hasInitialData = false;

  /// Record listener controller.
  RecordListenerController(DatabaseListener listener, this.recordRef,
      {required super.onListen}) {
    _streamController = StreamController<RecordSnapshot<K, V>?>(onCancel: () {
      if (debugListener) {
        // ignore: avoid_print
        print('onCancel $this');
      }
      // Auto remove
      listener.removeRecord(this);
      close();
    }, onListen: () {
      if (debugListener) {
        // ignore: avoid_print
        print('onListen $this');
      }
      onListen!();
    });
  }

  /// Add a snapshot if not deleted
  void add(RecordSnapshot? snapshot) {
    assert(lock.inLock);
    if (!_shouldAdd) {
      return;
    }
    hasInitialData = true;
    _streamController.add(snapshot?.cast<K, V>());
  }

  @override
  String toString() => 'RecordListenerController($_id)';

  /// Update the record.
  void update(ImmutableSembastRecord record) {
    lock.synchronized(() {
      if (debugListener) {
        // ignore: avoid_print
        print('updating $this: with $record');
      }

      if (!record.deleted) {
        add(record);
      } else {
        add(null);
      }
    });
  }
}

/// Store listener.
class StoreListener {
  /// Our store.
  final StoreRef<Key?, Value?> store;
  final _records = <Object?, List<RecordListenerController>>{};
  final _stores = <StoreListenerController>[];

  /// Store listener.
  StoreListener(this.store);

  /// Add a record.
  RecordListenerController<K, V> addRecord<K, V>(
      RecordRef<K, V> recordRef, RecordListenerController<K, V> ctlr) {
    var key = recordRef.key;
    var list = _records[key];
    if (list == null) {
      list = <RecordListenerController>[];
      _records[key] = list;
    }
    list.add(ctlr);
    return ctlr;
  }

  /// Add a query.
  StoreListenerController<K, V> addQuery<K, V>(
      StoreListenerController<K, V> ctlr) {
    _stores.add(ctlr);
    return ctlr;
  }

  /// Remove a query.
  void removeStore(StoreListenerController ctlr) {
    ctlr.close();
    _stores.remove(ctlr);
  }

  /// Remove a record.
  void removeRecord(RecordListenerController ctlr) {
    ctlr.close();
    var key = ctlr.recordRef.key;
    var list = _records[key];
    if (list != null) {
      list.remove(ctlr);
      if (list.isEmpty) {
        _records.remove(key);
      }
    }
  }

  /// All record keys being watched
  Iterable<Object?> get recordKeys => _records.keys;

  /// Get the record listener.
  List<RecordListenerController<K, V>>? getRecordControllers<K, V>(
      RecordRef<K, V> recordRef) {
    return _records[recordRef.key]?.cast<RecordListenerController<K, V>>();
  }

  /// True if record has a listener.
  bool keyHasRecordListener(dynamic key) => _records.containsKey(key);

  /// True if record has a listener.
  bool keyHasAnyListener(dynamic key) =>
      hasStoreListener || keyHasRecordListener(key);

  /// True if there is a query listener
  bool get hasStoreListener => _stores.isNotEmpty;

  /// Get list of query listeners, never null
  List<StoreListenerController<K, V>> getStoreListenerControllers<K, V>() {
    return _stores.cast<StoreListenerController<K, V>>();
  }

  /// true if empty.
  bool get isEmpty => _records.isEmpty && _stores.isEmpty;

  /// Restart listening on the store and its records.
  void restart() {
    for (var list in _records.values) {
      for (var recordController in list) {
        recordController.restart();
      }
    }
    for (var queryController in _stores) {
      queryController.restart();
    }
  }
}

/// Database listener.
class DatabaseListener {
  final _stores = <StoreRef, StoreListener>{};

  /// true if not empty.
  bool get isNotEmpty => _stores.isNotEmpty;

  /// true if empty.
  bool get isEmpty => _stores.isEmpty;

  /// Add a record.
  RecordListenerController<K, V> addRecord<K, V>(RecordRef<K, V> recordRef,
      {required void Function()? onListen}) {
    var ctlr =
        RecordListenerController<K, V>(this, recordRef, onListen: onListen);
    var storeRef = recordRef.store;
    var store = _stores[storeRef];
    if (store == null) {
      store = StoreListener(storeRef);
      _stores[storeRef] = store;
    }
    return store.addRecord<K, V>(recordRef, ctlr);
  }

  /// Add a query.
  QueryListenerController<K, V> addQuery<K, V>(QueryRef<K, V> queryRef,
      {required void Function()? onListen}) {
    var ctlr = newQuery(queryRef, onListen: onListen);
    addQueryController(ctlr);
    return ctlr;
  }

  /// Add a query.
  QueryKeysListenerController<K, V> addQueryKeys<K, V>(QueryRef<K, V> queryRef,
      {required void Function()? onListen}) {
    var ctlr = newQueryKeys(queryRef, onListen: onListen);
    addQueryController(ctlr);
    return ctlr;
  }

  /// Create a query.
  QueryListenerController<K, V> newQuery<K, V>(QueryRef<K, V> queryRef,
      {required void Function()? onListen}) {
    var ref = queryRef as SembastQueryRef<K, V>;
    var ctlr =
        QueryListenerController<K, V>(this, queryRef: ref, onListen: onListen);
    return ctlr;
  }

  /// Create a query key.
  QueryKeysListenerController<K, V> newQueryKeys<K, V>(QueryRef<K, V> queryRef,
      {required void Function()? onListen}) {
    var ref = queryRef as SembastQueryRef<K, V>;
    var ctlr = QueryKeysListenerController<K, V>(this,
        queryRef: ref, onListen: onListen);
    return ctlr;
  }

  /// Add a query controller.
  void addQueryController<K, V>(StoreListenerController<K, V> ctlr) {
    var storeRef = ctlr.storeRef;
    var store = _stores[storeRef];
    if (store == null) {
      store = StoreListener(storeRef);
      _stores[storeRef] = store;
    }
    store.addQuery<K, V>(ctlr);
  }

  /// Add a count.
  CountListenerController<K, V> addCount<K, V>(FilterRef<K, V> filterRef,
      {required void Function()? onListen}) {
    var ctlr = newCount(filterRef, onListen: onListen);
    addQueryController(ctlr);
    return ctlr;
  }

  /// Create a query.
  CountListenerController<K, V> newCount<K, V>(FilterRef<K, V> filterRef,
      {required void Function()? onListen}) {
    var ctlr = CountListenerController<K, V>(this,
        filterRef: filterRef as SembastFilterRef<K, V>, onListen: onListen);
    return ctlr;
  }

  /// Remove a record controller.
  void removeRecord(RecordListenerController ctlr) {
    ctlr.close();
    var recordRef = ctlr.recordRef;
    var storeRef = recordRef.store;
    var store = _stores[storeRef];
    if (store != null) {
      store.removeRecord(ctlr);
      if (store.isEmpty) {
        _stores.remove(storeRef);
      }
    }
  }

  /// remove a query controller.
  void removeStore(StoreListenerController ctlr) {
    ctlr.close();
    var storeRef = ctlr.storeRef;
    var store = _stores[storeRef];
    if (store != null) {
      store.removeStore(ctlr);
      if (store.isEmpty) {
        _stores.remove(storeRef);
      }
    }
  }

  /// Get a record controller.
  List<RecordListenerController<K, V>>? getRecord<K, V>(
      RecordRef<K, V> recordRef) {
    return _stores[recordRef as StoreRef<Object?, Object?>]!
        .getRecordControllers(recordRef)
        ?.cast<RecordListenerController<K, V>>();
  }

  /// Get a store listener.
  StoreListener? getStore(StoreRef<Key?, Value?> ref) => _stores[ref];

  /// All store listeners.
  Iterable<StoreRef> get stores => _stores.keys;

  /// Close and clear listeners.
  void close() {
    for (var storeListener in _stores.values) {
      for (var queryListener in storeListener._stores) {
        queryListener.close();
      }
      for (var recordListeners in storeListener._records.values) {
        for (var recordListener in recordListeners) {
          recordListener.close();
        }
      }
    }
    _stores.clear();
  }

  /// True if the record as a listener
  bool recordHasAnyListener(RecordRef<Key?, Value?> record) =>
      getStore(record.store)?.keyHasAnyListener(record.key) ?? false;
}

/// Query listener controller.
class CountListenerController<K, V>
    extends _StoreListenerControllerBase<K, V, int> {
  /// The query.

  final SembastFilterRef<K, V> filterRef;

  /// The filter
  Filter? get filter => filterRef.filter;

  /// True when the first data has arrived
  @override
  bool get hasInitialData => list != null;

  /// The current list
  Set<Object?>? list;

  /// Last count
  int? lastCount;

  /// Count listener controller.
  CountListenerController(super.listener,
      {required this.filterRef, required super.onListen});

  /// The filter.
  SembastFilterBase? get filterBase => filter as SembastFilterBase?;

  /// Add data to stream, allMatching is already sorted
  void add(Set<Object?> keys, Cooperator? cooperator) {
    assert(lock.inLock);
    var changed = list?.length != keys.length;
    // Filter only
    list = keys;
    //var list = recordsLimit(_allMatching, finder);

    // devPrint('adding $allMatching / limit $list / $finder');
    if (changed && _shouldAdd) {
      _streamController.add(keys.length);
    }
  }

  /// Update the records.
  ///
  /// We are async safe here
  @override
  Future update(
      Iterable<ImmutableSembastRecord> records, Cooperator? cooperator) async {
    if (!_shouldAdd) {
      return;
    }
    await lock.synchronized(() async {
      var keys = Set<Object>.from(list!);

      for (var record in records) {
        if (!record.deleted && filterMatchesRecord(filter, record)) {
          keys.add(record.key);
        } else {
          keys.remove(record.key);
        }
      }

      for (var txnRecord in records) {
        var key = txnRecord.key;

        // By default matches if non-deleted
        var matches =
            !txnRecord.deleted && filterMatchesRecord(filter, txnRecord);

        if (matches) {
          keys.add(key);
        } else {
          keys.remove(key);
        }

        if (cooperator?.needCooperate ?? false) {
          await cooperator!.cooperate();
        }
        if (isClosed) {
          return;
        }
      }
      add(keys, cooperator);
    });
  }

  @override
  String toString() => 'CountListenerCtlr($_id)';

  @override
  StoreRef<K, V> get storeRef => filterRef.store;
}
