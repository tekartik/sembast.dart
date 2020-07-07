import 'package:meta/meta.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/query_ref.dart';
import 'package:sembast/src/api/record_ref.dart';
import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/cooperator.dart';
import 'package:sembast/src/debug_utils.dart';
import 'package:sembast/src/filter_impl.dart';
import 'package:sembast/src/finder_impl.dart';
import 'package:sembast/src/query_ref_impl.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/sort.dart';
import 'package:sembast/src/utils.dart';

class _ControllerBase {
  static var _lastId = 0;

  /// Debug only
  int _id;

  _ControllerBase() {
    _id = ++_lastId;
  }
}

/// Query listener controller.
class QueryListenerController<K, V> extends _ControllerBase {
  /// onListen to start or restart query.
  void Function() onListen;

  /// The query.
  final SembastQueryRef<K, V> queryRef;
  StreamController<List<RecordSnapshot<K, V>>> _streamController;

  /// True when the first data has arrived
  bool get hasInitialData => _allMatching != null;

  /// true if closed.
  bool get isClosed => _streamController.isClosed;

  /// The current list
  List<RecordSnapshot<K, V>> list;
  List<ImmutableSembastRecord> _allMatching;

  /// The finder.
  // ignore: deprecated_member_use_from_same_package
  SembastFinder get finder => queryRef.finder;

  /// The filter.
  SembastFilterBase get filter => finder?.filter as SembastFilterBase;

  /// close controller.
  void close() {
    _streamController?.close();
  }

  /// Query listener controller.
  QueryListenerController(DatabaseListener listener, this.queryRef,
      {@required this.onListen}) {
    // devPrint('query $queryRef');

    _streamController =
        StreamController<List<RecordSnapshot<K, V>>>(onCancel: () {
      // Auto remove
      if (debugListener) {
        print('onCancel $this');
      }
      listener.removeQuery(this);
      close();
    }, onListen: () {
      if (debugListener) {
        print('onListen $this');
      }
      onListen();
    });
  }

  /// stream.
  Stream<List<RecordSnapshot<K, V>>> get stream => _streamController.stream;

  bool get _shouldAdd => !isClosed && _streamController.hasListener;

  /// Add data to stream, allMatching is already sorted
  Future add(
      List<ImmutableSembastRecord> allMatching, Cooperator cooperator) async {
    if (!_shouldAdd) {
      return;
    }

    // Filter only
    _allMatching = allMatching;
    var list = await recordsLimit(_allMatching, finder, cooperator);

    if (!_shouldAdd) {
      return;
    }

    // devPrint('adding $allMatching / limit $list / $finder');
    _streamController?.add(immutableListToSnapshots<K, V>(list));
  }

  /// Add error.
  void addError(dynamic error, StackTrace stackTrace) {
    if (!_shouldAdd) {
      return;
    }
    _streamController.addError(error, stackTrace);
  }

  /// Update the records.
  ///
  /// We are async safe here
  Future update(
      Iterable<ImmutableSembastRecord> records, Cooperator cooperator) async {
    if (!_shouldAdd) {
      return;
    }

    var hasChanges = false;

    // Restart from the base we have for efficiency
    var allMatching = List<ImmutableSembastRecord>.from(_allMatching);

    var keys = Set.from(records.map((record) => record.key));
    // Remove all matching
    bool _where(snapshot) {
      if (keys.contains(snapshot.key)) {
        hasChanges = true;
        return true;
      }
      return false;
    }

    // Remove and reinsert if needed
    allMatching.removeWhere(_where);

    for (var txnRecord in records) {
      if (!_shouldAdd) {
        return;
      }

      // By default matches if non-deleted
      var matches =
          !txnRecord.deleted && filterMatchesRecord(filter, txnRecord);

      if (matches) {
        hasChanges = true;
        // insert at the proper location
        allMatching.insert(
            findSortedIndex(allMatching, txnRecord,
                finder?.compareThenKey ?? compareRecordKey),
            txnRecord);
      }

      if (cooperator?.needCooperate ?? false) {
        await cooperator.cooperate();
      }
    }
    if (isClosed) {
      return;
    }
    if (hasChanges) {
      await add(allMatching, cooperator);
    }
  }

  @override
  String toString() => 'QueryListenerCtlr($_id)';

  /// Restart controller.
  void restart() {
    if (_shouldAdd) {
      if (debugListener) {
        print('restarting listener $this');
      }
      onListen();
    }
  }
}

/// Record listener controller.
class RecordListenerController<K, V> extends _ControllerBase {
  /// The record ref.
  final RecordRef<K, V> recordRef;

  /// Start or restart
  void Function() onListen;

  /// has initial data.
  bool hasInitialData = false;
  StreamController<RecordSnapshot<K, V>> _streamController;

  /// close.
  void close() {
    _streamController.close();
  }

  /// True if controller closed.
  bool get isClosed => _streamController.isClosed;

  /// Record listener controller.
  RecordListenerController(DatabaseListener listener, this.recordRef,
      {@required this.onListen}) {
    _streamController = StreamController<RecordSnapshot<K, V>>(onCancel: () {
      if (debugListener) {
        print('onCancel $this');
      }
      // Auto remove
      listener.removeRecord(this);
      close();
    }, onListen: () {
      if (debugListener) {
        print('onListen $this');
      }
      onListen();
    });
  }

  /// stream.
  Stream<RecordSnapshot<K, V>> get stream => _streamController.stream;

  /// True if should add or start listening.
  bool get _shouldAdd => !isClosed && _streamController.hasListener;

  /// Add a snapshot if not deleted
  void add(RecordSnapshot snapshot) {
    if (!_shouldAdd) {
      return;
    }
    hasInitialData = true;
    _streamController.add(snapshot?.cast<K, V>());
  }

  /// Add an error.
  void addError(dynamic error, StackTrace stackTrace) {
    if (!_shouldAdd) {
      return;
    }
    _streamController.addError(error, stackTrace);
  }

  @override
  String toString() => 'RecordListenerController($_id)';

  /// Restart controller.
  void restart() {
    if (_shouldAdd) {
      if (debugListener) {
        print('restarting listener $this');
      }
      onListen();
    }
  }
}

/// Store listener.
class StoreListener {
  /// Our store.
  final StoreRef store;
  final _records = <dynamic, List<RecordListenerController>>{};
  final _queries = <QueryListenerController>[];

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
  QueryListenerController<K, V> addQuery<K, V>(
      QueryListenerController<K, V> ctlr) {
    _queries.add(ctlr);
    return ctlr;
  }

  /// Remove a query.
  void removeQuery(QueryListenerController ctlr) {
    ctlr.close();
    _queries.remove(ctlr);
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
  Iterable<dynamic> get recordKeys => _records.keys;

  /// Get the record listener.
  List<RecordListenerController<K, V>> getRecordControllers<K, V>(
      RecordRef<K, V> recordRef) {
    return _records[recordRef.key]?.cast<RecordListenerController<K, V>>();
  }

  /// True if record has a listener.
  bool keyHasRecordListener(dynamic key) => _records.containsKey(key);

  /// True if record has a listener.
  bool keyHasAnyListener(dynamic key) =>
      hasQueryListener || keyHasRecordListener(key);

  /// True if there is a query listener
  bool get hasQueryListener => _queries.isNotEmpty;

  /// Get list of query listeners, never null
  List<QueryListenerController<K, V>> getQueryListenerControllers<K, V>() {
    return _queries.cast<QueryListenerController<K, V>>();
  }

  /// true if empty.
  bool get isEmpty => _records.isEmpty && _queries.isEmpty;

  /// Restart listening on the store and its records.
  void restart() {
    for (var list in _records.values) {
      for (var recordController in list) {
        recordController.restart();
      }
    }
    for (var queryController in _queries) {
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
      {@required void Function() onListen}) {
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
      {@required void Function() onListen}) {
    var ctlr = newQuery(queryRef, onListen: onListen);
    addQueryController(ctlr);
    return ctlr;
  }

  /// Create a query.
  QueryListenerController<K, V> newQuery<K, V>(QueryRef<K, V> queryRef,
      {@required void Function() onListen}) {
    var ref = queryRef as SembastQueryRef<K, V>;
    var ctlr = QueryListenerController<K, V>(this, ref, onListen: onListen);
    return ctlr;
  }

  /// Add a query controller.
  void addQueryController<K, V>(QueryListenerController<K, V> ctlr) {
    var storeRef = ctlr.queryRef.store;
    var store = _stores[storeRef];
    if (store == null) {
      store = StoreListener(storeRef);
      _stores[storeRef] = store;
    }
    store.addQuery<K, V>(ctlr);
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
  void removeQuery(QueryListenerController ctlr) {
    ctlr.close();
    var storeRef = ctlr.queryRef.store;
    var store = _stores[storeRef];
    if (store != null) {
      store.removeQuery(ctlr);
      if (store.isEmpty) {
        _stores.remove(storeRef);
      }
    }
  }

  /// Get a record controller.
  List<RecordListenerController<K, V>> getRecord<K, V>(
      RecordRef<K, V> recordRef) {
    return _stores[recordRef]
        .getRecordControllers(recordRef)
        ?.cast<RecordListenerController<K, V>>();
  }

  /// Get a store listener.
  StoreListener getStore(StoreRef ref) => _stores[ref];

  /// All store listeners.
  Iterable<StoreRef> get stores => _stores.keys;

  /// Close and clear listeners.
  void close() {
    _stores.values.forEach((storeListener) {
      storeListener._queries.forEach((queryListener) {
        queryListener.close();
      });
      storeListener._records.values.forEach((recordListeners) {
        recordListeners.forEach((recordListener) => recordListener.close());
      });
    });
    _stores.clear();
  }

  /// True if the record as a listener
  bool recordHasAnyListener(RecordRef record) =>
      getStore(record.store)?.keyHasAnyListener(record.key) ?? false;
}
