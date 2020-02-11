import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/query_ref.dart';
import 'package:sembast/src/api/record_ref.dart';
import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/cooperator.dart';
import 'package:sembast/src/filter_impl.dart';
import 'package:sembast/src/finder_impl.dart';
import 'package:sembast/src/query_ref_impl.dart';
import 'package:sembast/src/record_impl.dart';

// ignore_for_file: deprecated_member_use_from_same_package

/// Query listener controller.
class QueryListenerController<K, V> {
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
  SembastFinder get finder => queryRef.finder;

  /// The filter.
  SembastFilterBase get filter => finder?.filter as SembastFilterBase;

  /// close controller.
  void close() {
    _streamController?.close();
  }

  /// Query listener controller.
  QueryListenerController(DatabaseListener listener, this.queryRef) {
    // devPrint('query $queryRef');
    _streamController =
        StreamController<List<RecordSnapshot<K, V>>>(onCancel: () {
      // Auto remove
      listener.removeQuery(this);
      close();
    });
  }

  /// stream.
  Stream<List<RecordSnapshot<K, V>>> get stream => _streamController.stream;

  bool get _shouldAdd => !isClosed && _streamController.hasListener;

  /// Add data to stream.
  Future add(
      List<ImmutableSembastRecord> allMatching, Cooperator cooperator) async {
    if (!_shouldAdd) {
      return;
    }

    // Filter only
    _allMatching = allMatching;
    var list = await sortAndLimit(_allMatching, finder, cooperator);

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
      List<ImmutableSembastRecord> records, Cooperator cooperator) async {
    if (isClosed) {
      return;
    }
    // Restart from the base we have for efficiency
    var allMatching = List<ImmutableSembastRecord>.from(_allMatching);
    var hasChanges = false;
    for (var txnRecord in records) {
      if (isClosed) {
        return;
      }
      var ref = txnRecord.ref;

      bool _where(snapshot) {
        if (snapshot.ref == ref) {
          hasChanges = true;
          return true;
        }
        return false;
      }

      // Remove and reinsert if needed
      allMatching.removeWhere(_where);

      // By default matches if non-deleted
      var matches = !txnRecord.deleted;
      if (matches && filter != null) {
        matches = filterMatchesRecord(filter, txnRecord);
      }

      if (matches) {
        hasChanges = true;
        // re-add
        allMatching.add(txnRecord);
      }

      await cooperator.cooperate();
    }
    if (isClosed) {
      return;
    }
    if (hasChanges) {
      await add(allMatching, cooperator);
    }
  }
}

/// Record listener controller.
class RecordListenerController<K, V> {
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
  RecordListenerController(
      DatabaseListener listener, RecordRef<K, V> recordRef) {
    _streamController = StreamController<RecordSnapshot<K, V>>(onCancel: () {
      // devPrint('onCancel');
      // Auto remove
      listener.removeRecord(recordRef, this);
      close();
    });
  }

  /// stream.
  Stream<RecordSnapshot<K, V>> get stream => _streamController.stream;

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
}

/// Store listener.
class StoreListener {
  final _records = <dynamic, List<RecordListenerController>>{};
  final _queries = <QueryListenerController>[];

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
  void removeRecord(RecordRef recordRef, RecordListenerController ctlr) {
    ctlr.close();
    var key = recordRef.key;
    var list = _records[key];
    if (list != null) {
      list.remove(ctlr);
      if (list.isEmpty) {
        _records.remove(key);
      }
    }
  }

  /// Get the records.
  List<RecordListenerController<K, V>> getRecord<K, V>(
      RecordRef<K, V> recordRef) {
    return _records[recordRef.key]?.cast<RecordListenerController<K, V>>();
  }

  /// Get list of query listeners, never null
  List<QueryListenerController<K, V>> getQuery<K, V>() {
    return _queries.cast<QueryListenerController<K, V>>();
  }

  /// true if empty.
  bool get isEmpty => _records.isEmpty && _queries.isEmpty;
}

/// Database listener.
class DatabaseListener {
  final _stores = <StoreRef, StoreListener>{};

  /// true if not empty.
  bool get isNotEmpty => _stores.isNotEmpty;

  /// true if empty.
  bool get isEmpty => _stores.isEmpty;

  /// Add a record.
  RecordListenerController<K, V> addRecord<K, V>(RecordRef<K, V> recordRef) {
    var ctlr = RecordListenerController<K, V>(this, recordRef);
    var storeRef = recordRef.store;
    var store = _stores[storeRef];
    if (store == null) {
      store = StoreListener();
      _stores[storeRef] = store;
    }
    return store.addRecord<K, V>(recordRef, ctlr);
  }

  /// Add a query.
  QueryListenerController<K, V> addQuery<K, V>(QueryRef<K, V> queryRef) {
    var ctlr = newQuery(queryRef);
    addQueryController(ctlr);
    return ctlr;
  }

  /// Create a query.
  QueryListenerController<K, V> newQuery<K, V>(QueryRef<K, V> queryRef) {
    var ref = queryRef as SembastQueryRef<K, V>;
    var ctlr = QueryListenerController<K, V>(this, ref);
    return ctlr;
  }

  /// Add a query controller.
  void addQueryController<K, V>(QueryListenerController<K, V> ctlr) {
    var storeRef = ctlr.queryRef.store;
    var store = _stores[storeRef];
    if (store == null) {
      store = StoreListener();
      _stores[storeRef] = store;
    }
    store.addQuery<K, V>(ctlr);
  }

  /// Remove a record controller.
  void removeRecord(RecordRef recordRef, RecordListenerController ctlr) {
    ctlr.close();
    var storeRef = recordRef.store;
    var store = _stores[storeRef];
    if (store != null) {
      store.removeRecord(recordRef, ctlr);
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
        .getRecord(recordRef)
        ?.cast<RecordListenerController<K, V>>();
  }

  /// Get a store listener.
  StoreListener getStore(StoreRef ref) => _stores[ref];

  /// Closed.
  void close() {
    _stores.values.forEach((storeListener) {
      storeListener._queries.forEach((queryListener) {
        queryListener.close();
      });
      storeListener._records.values.forEach((recordListeners) {
        recordListeners.forEach((recordListener) => recordListener.close());
      });
    });
  }
}

/// Store listener operation.
class StoreListenerOperation {
  /// Store listener.
  final StoreListener listener;

  /// records changes.
  final List<ImmutableSembastRecord> txnRecords;

  /// Store listener operation.
  StoreListenerOperation(this.listener, this.txnRecords);
}
