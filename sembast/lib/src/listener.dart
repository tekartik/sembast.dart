import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/record_ref.dart';
import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/record_impl.dart';

class RecordListenerController<K, V> {
  StreamController<RecordSnapshot<K, V>> _streamController;

  void close() {
    _streamController?.close();
  }

  RecordListenerController(
      DatabaseListener listener, RecordRef<K, V> recordRef) {
    _streamController = StreamController<RecordSnapshot<K, V>>(onCancel: () {
      // Auto remove
      listener.removeRecord(recordRef, this);
      _streamController = null;
    });
  }

  Stream<RecordSnapshot<K, V>> get stream => _streamController.stream;

  void add(RecordSnapshot recordSnapshot) {
    _streamController.add(recordSnapshot?.cast<K, V>());
  }
}

class StoreListener {
  final _records = <dynamic, List<RecordListenerController>>{};

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

  List<RecordListenerController<K, V>> getRecord<K, V>(
      RecordRef<K, V> recordRef) {
    return _records[recordRef.key]?.cast<RecordListenerController<K, V>>();
  }

  bool get isEmpty => _records.isEmpty;
}

class DatabaseListener {
  final _stores = <StoreRef, StoreListener>{};

  bool get isNotEmpty => _stores.isNotEmpty;
  bool get isEmpty => _stores.isEmpty;

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

  List<RecordListenerController<K, V>> getRecord<K, V>(
      RecordRef<K, V> recordRef) {
    return _stores[recordRef]
        .getRecord(recordRef)
        ?.cast<RecordListenerController<K, V>>();
  }

  StoreListener getStore(StoreRef ref) => _stores[ref];
}

class StoreListenerOperation {
  final StoreListener listener;
  final List<TxnRecord> txnRecords;

  StoreListenerOperation(this.listener, this.txnRecords);
}
