library sembast.idb_database;

//import 'package:tekartik_core/dev_utils.dart';
import 'package:logging/logging.dart';
import 'package:idb_shim/idb_client.dart';
import 'package:sembast/database.dart' as sdb;
import 'dart:async';
import 'package:path/path.dart';
import '../../../idb_shim.dart/lib/src/common/common_meta.dart';

const IDB_FACTORY_SEMBAST = "sembast";

class _SdbVersionChangeEvent extends VersionChangeEvent {

  final int oldVersion;
  final int newVersion;
  Request request;
  Object get target => request;
  Database get database => transaction.database;
  /**
     * added for convenience
     */
  _SdbTransaction get transaction => request.transaction;

  _SdbVersionChangeEvent(_SdbDatabase database, int oldVersion, this.newVersion) //
      : oldVersion = oldVersion == null ? 0 : oldVersion {

    // handle = too to catch programatical errors
    if (this.oldVersion >= newVersion) {
      throw new StateError("cannot downgrade from ${oldVersion} to $newVersion");
    }
    request = new OpenDBRequest(database, database.versionChangeTransaction);
  }
  @override
  String toString() {
    return "${oldVersion} => ${newVersion}";
  }
}

class _SdbTransaction extends Transaction {

  _SdbDatabase get database => super.database as _SdbDatabase;
  sdb.Database get sdbDatabase => database.db;


  int index = 0;

  _execute(i) {
    if (database.LOGV) {
      _SdbDatabase.logger.finest("exec $i");
    }
    Completer completer = completers[i];
    Function action = actions[i];
    return new Future.sync(action).then((result) {
      if (database.LOGV) {
        _SdbDatabase.logger.finest("done $i");
      }
      completer.complete(result);
    }).catchError((e) {
      //devPrint(" err $i");
      if (database.LOGV) {
        _SdbDatabase.logger.finest("err $i");
      }
      completer.completeError(e);
    });
  }

  _next() {
    //print('_next? ${index}/${actions.length}');
    if (index < actions.length) {
      // Always try more
      return _execute(index++).then((_) {
        return _next();
      });
    } else {
      // check next cycle too
      return new Future.value().then((_) {
        if (index < actions.length) {
          return _next();
        }
      });
    }
  }

  // Lazy execution of the first action
  Future lazyExecution;

  //
  // Create or execute the transaction
  // leaving a time to breath
  // Since it must run everything in a single call, let all the actions
  // in the first callback enqueue before running
  //
  Future execute(action()) {

    Future actionFuture = _enqueue(action);
    futures.add(actionFuture);

    if (lazyExecution == null) {
      // don't return the result here
      lazyExecution = new Future.microtask(() {
        assert(sdbDatabase.transaction == null);

        // No return value here
        return sdbDatabase.inTransaction(() {

          // assign right away as this is tested
          sdbTransaction = sdbDatabase.transaction;

          return _next();



//
//          _checkNext() {
//            _next();
//            if (index < actions.length) {
//              return new Future.sync(_next());
//            }
//
//                return finalResult;
//
//              }();
//                    }
//
//          return _checkNext();
        });

      });
      //return lazyExecution;
    }

    return actionFuture;

  }

  _enqueue(action()) {
// not lazy
    Completer completer = new Completer.sync();
    completers.add(completer);
    actions.add(action);
    //devPrint("push ${actions.length}");
    //_next();
    return completer.future.then((result) {
      // re-push termination check
      //print(result);
      return result;
    });
  }
  sdb.Transaction sdbTransaction;
  List<Completer> completers = [];
  List<Function> actions = [];
  List<Future> futures = [];

  final IdbTransactionMeta meta;
  _SdbTransaction(_SdbDatabase database, this.meta) : super(database);

  Future<Database> get _completed {
    if (lazyExecution == null) {
      return new Future.value(database);
    }
    return lazyExecution.then((_) {
      return sdbTransaction.completed.then((_) {
        return Future.wait(futures).then((_) {
          return database;
        }).catchError((e, st) {
          // catch any errors
          // this is needed so that completed always complete
          // without error
        });
      });
    });
  }

  @override
  Future<Database> get completed {
    // postpone to next 2 cycles to allow enqueing
    // actions after completed has been called
    return new Future.value().then((_) => _completed);

  }

//    sdbTransaction == null ? new Future.value(database) : sdbTransaction.completed.then((_) {
//    // delay the completed event
//
//  });

  @override
  ObjectStore objectStore(String name) {
    return new _SdbObjectStore(this, database.meta.getObjectStore(name));
  }

//  @override
//  String toString() {
//    return
//  }
}

class _SdbIndex extends Index {

  final _SdbObjectStore store;
  final IdbIndexMeta meta;

  _SdbIndex(this.store, this.meta);

  Future inTransaction(Future computation()) {
    return store.inTransaction(computation);
  }

  _indexKeyOrRangeFilter([key_OR_range]) {
    // null means all entry without null value
    if (key_OR_range == null) {
      return new sdb.Filter.notEqual(meta.keyPath, null);
    }
    return _keyOrRangeFilter(meta.keyPath, key_OR_range);
  }

  @override
  Future<int> count([key_OR_range]) {
    return inTransaction(() {
      return store.sdbStore.count(_indexKeyOrRangeFilter(key_OR_range));
    });
  }

  @override
  Future get(key) {
    return inTransaction(() {
      sdb.Finder finder = new sdb.Finder(filter: _indexKeyOrRangeFilter(key), limit: 1);
      return store.sdbStore.findRecords(finder).then((List<sdb.Record> records) {
        if (records.isNotEmpty) {
          return records.first.value;
        }
      });
    });
  }

  @override
  Future getKey(key) {
    return inTransaction(() {
      sdb.Finder finder = new sdb.Finder(filter: _indexKeyOrRangeFilter(key), limit: 1);
      return store.sdbStore.findRecords(finder).then((List<sdb.Record> records) {
        if (records.isNotEmpty) {
          return records.first.key;
        }
      });
    });
  }

  @override
  get keyPath => meta.keyPath;

  @override
  bool get multiEntry => meta.multiEntry;

  @override
  String get name => meta.name;

  @override
  Stream<CursorWithValue> openCursor({key, KeyRange range, String direction, bool autoAdvance}) {
    IdbCursorMeta cursorMeta = new IdbCursorMeta(key, range, direction, autoAdvance);
    _SdbIndexCursorWithValueController ctlr = new _SdbIndexCursorWithValueController(this, cursorMeta);

    inTransaction(() {
      return ctlr.openCursor();
    });

    return ctlr.stream;
  }

  @override
  Stream<Cursor> openKeyCursor({key, KeyRange range, String direction, bool autoAdvance}) {
    IdbCursorMeta cursorMeta = new IdbCursorMeta(key, range, direction, autoAdvance);
    _SdbIndexKeyCursorController ctlr = new _SdbIndexKeyCursorController(this, cursorMeta);

    inTransaction(() {
      return ctlr.openCursor();
    });

    return ctlr.stream;
  }

  @override
  bool get unique => meta.unique;

  sdb.Filter cursorFilter(key, KeyRange range) {
    return _keyCursorFilter(keyPath, key, range);
  }

  sdb.SortOrder sortOrder(bool ascending) {
    return new sdb.SortOrder(keyPath, ascending);
  }
}

sdb.Filter _keyCursorFilter(String keyField, key, KeyRange range) {
  sdb.Filter filter;
  if (range != null) {
    return _keyRangeFilter(keyField, range);
  } else {
    return _keyFilter(keyField, key);

  }
}

sdb.Filter _keyRangeFilter(String keyPath, KeyRange range) {
  sdb.Filter lowerFilter;
  sdb.Filter upperFilter;
  List<sdb.Filter> filters = [];
  if (range.lower != null) {
    if (range.lowerOpen == true) {
      lowerFilter = new sdb.Filter.greaterThan(keyPath, range.lower);
    } else {
      lowerFilter = new sdb.Filter.greaterThanOrEquals(keyPath, range.lower);
    }
    filters.add(lowerFilter);
  }
  if (range.upper != null) {
    if (range.upperOpen == true) {
      upperFilter = new sdb.Filter.lessThan(keyPath, range.upper);
    } else {
      upperFilter = new sdb.Filter.lessThanOrEquals(keyPath, range.upper);
    }
    filters.add(upperFilter);
  }
  return new sdb.Filter.and(filters);
}

sdb.Filter _keyFilter(String keyPath, var key) {
  if (key == null) {
    return null;
  }
  return new sdb.Filter.equal(keyPath, key);
}

sdb.Filter _keyOrRangeFilter(String keyPath, [key_OR_range]) {
  if (key_OR_range is KeyRange) {
    return _keyRangeFilter(keyPath, key_OR_range);
  } else {
    return _keyFilter(keyPath, key_OR_range);
  }
}

//abstract class IdbCursor {
//  //
//  // Idb redefinition
//  //
//  String get direction;
//  void advance(int count);
//  Future delete();
//  void next();
//  Object get primaryKey;
//  Object get key;
//  Future update(value);
//  //Object get value;
//}

abstract class _SdbKeyCursorMixin implements Cursor {
  // set upon creation
  int recordIndex;
  _SdbBaseCursorControllerMixin ctlr;

  _SdbObjectStore get store => ctlr.store;
  IdbCursorMeta get meta => ctlr.meta;

  sdb.Record get record => ctlr.records[recordIndex];
  //
  // Idb
  //
  @override
  String get direction => meta.direction;
  void advance(int count) {
    // no future
    ctlr.advance(count);
  }

  @override
  void next() => advance(1);

  @override
  Future delete() {
    return store.delete(record.key);
  }

  @override
  Object get key => record.key;


  @override
  Object get primaryKey => record.key;

  @override
  Future update(value) => store.put(value, primaryKey);


}

abstract class _SdbIndexCursorMixin implements Cursor {
  _SdbIndexCursorControllerMixin get indexCtlr;
  _SdbIndex get index => indexCtlr.index;
  sdb.Record get record;

///
/// Return the index key of the record
///
  @override
  Object get key => record.value[index.keyPath];
}

abstract class _SdbCursorWithValueMixin implements CursorWithValue {
  sdb.Record get record;

  @override
  Object get value => record.value;
}

class _SdbIndexKeyCursor extends Object with _SdbKeyCursorMixin, _SdbIndexCursorMixin implements Cursor {
  _SdbIndexKeyCursorController get indexCtlr => ctlr;

  _SdbIndexKeyCursor(_SdbIndexKeyCursorController ctlr, int index) {
    this.ctlr = ctlr;
    this.recordIndex = index;
  }

  ///
  /// Return the index key of the record
  ///
  @override
  Object get key => record.value[indexCtlr.index.keyPath];
}

class _SdbStoreKeyCursor extends Object with _SdbKeyCursorMixin implements Cursor {
  _SdbStoreKeyCursor(_SdbBaseCursorControllerMixin ctlr, int index) {
    this.ctlr = ctlr;
    this.recordIndex = index;
  }
}

class _SdbIndexCursorWithValue extends Object with _SdbKeyCursorMixin, _SdbCursorWithValueMixin {
  _SdbIndexCursorWithValueController get indexCtlr => ctlr;
  _SdbIndexCursorWithValue(_SdbBaseCursorControllerMixin ctlr, int index) {
    this.ctlr = ctlr;
    this.recordIndex = index;
  }

  ///
  /// Return the index key of the record
  ///
  @override
  Object get key => record.value[indexCtlr.index.keyPath];

}

class _SdbStoreCursorWithValue extends Object with _SdbKeyCursorMixin, _SdbCursorWithValueMixin {
  _SdbStoreCursorWithValue(_SdbBaseCursorControllerMixin ctlr, int index) {
    this.ctlr = ctlr;
    this.recordIndex = index;
  }
}


class _SdbCursorWithValue extends Object with _SdbKeyCursorMixin, _SdbCursorWithValueMixin {
  _SdbCursorWithValue(_SdbBaseCursorControllerMixin ctlr, int index) {
    this.ctlr = ctlr;
    this.recordIndex = index;
  }
}

abstract class _ISdbCursor {
  sdb.Filter get filter;
  sdb.SortOrder get sortOrder;
}

abstract class _SdbIndexCursorControllerMixin implements _ISdbCursor {
  _SdbIndex index;
  IdbCursorMeta get meta;

  @override
  sdb.SortOrder get sortOrder {
    return index.sortOrder(meta.ascending);
  }

  @override
  sdb.Filter get filter {
    return index.cursorFilter(meta.key, meta.range);
  }
}

abstract class _SdbStoreCursorControllerMixin implements _ISdbCursor {
  _SdbObjectStore get store;
  IdbCursorMeta get meta;

  @override
  sdb.SortOrder get sortOrder {
    return store.sortOrder(meta.ascending);
  }

  @override
  sdb.Filter get filter {
    return store.cursorFilter(meta.key, meta.range);
  }
}


abstract class _SdbBaseCursorControllerMixin implements _ISdbCursor {
  IdbCursorMeta meta;
  _SdbObjectStore get store;

// To implement for KeyCursor vs CursorWithValue
  Cursor nextEvent(int index);

  List<sdb.Record> records;
  bool get done => currentIndex == null;
  int currentIndex = -1;
  StreamController ctlr;

  void init() {
    ctlr = new StreamController(sync: true);
  }


  Future autoNext() {
    return advance(1).then((_) {
      if (meta.autoAdvance && (!done)) {
        return autoNext();
      }
    });
  }


  Future advance(int count) {
    currentIndex += count;
    if (currentIndex >= records.length) {
      currentIndex = null;
      return ctlr.close();
    }

    ctlr.add(nextEvent(currentIndex));
    return new Future.value();

  }

  Future openCursor() {

    sdb.Filter filter = this.filter;
    sdb.SortOrder sortOrder = this.sortOrder;
    sdb.Finder finder = new sdb.Finder(filter: filter, sortOrders: [sortOrder]);
    return store.sdbStore.findRecords(finder).then((List<sdb.Record> records) {
      this.records = records;
      return autoNext();
    });
  }
}

abstract class _SdbKeyCursorControllerMixin {
  StreamController<Cursor> get ctlr;
  Stream<Cursor> get stream => ctlr.stream;
}

abstract class _SdbCursorWithValueControllerMixin {
  StreamController<CursorWithValue> get ctlr;
  Stream<CursorWithValue> get stream => ctlr.stream;
}

class _SdbStoreKeyCursorController extends Object with _SdbKeyCursorControllerMixin, _SdbBaseCursorControllerMixin, _SdbStoreCursorControllerMixin {
  _SdbObjectStore store;
  _SdbStoreKeyCursorController(this.store, IdbCursorMeta meta) {
    this.meta = meta;
    init();
  }

  Cursor nextEvent(int index) {
    _SdbStoreKeyCursor cursor = new _SdbStoreKeyCursor(this, index);
    return cursor;
  }
}

class _SdbIndexKeyCursorController extends Object with _SdbKeyCursorControllerMixin, _SdbBaseCursorControllerMixin, _SdbIndexCursorControllerMixin {
  _SdbIndex index;
  _SdbObjectStore get store => index.store;
  _SdbIndexKeyCursorController(_SdbIndex index, IdbCursorMeta meta) {
    this.meta = meta;
    this.index = index;
    init();
  }

  Cursor nextEvent(int index) {
    _SdbIndexKeyCursor cursor = new _SdbIndexKeyCursor(this, index);
    return cursor;
  }
}

class _SdbIndexCursorWithValueController extends Object with _SdbCursorWithValueControllerMixin, _SdbBaseCursorControllerMixin, _SdbIndexCursorControllerMixin {
  _SdbIndex index;
  _SdbObjectStore get store => index.store;
  _SdbIndexCursorWithValueController(this.index, IdbCursorMeta meta) {
    this.meta = meta;
    init();
  }

  Cursor nextEvent(int index) {
    _SdbIndexCursorWithValue cursor = new _SdbIndexCursorWithValue(this, index);
    return cursor;
  }
}
class _SdbStoreCursorWithValueController extends Object with _SdbCursorWithValueControllerMixin, _SdbBaseCursorControllerMixin, _SdbStoreCursorControllerMixin {
  _SdbObjectStore store;
  _SdbStoreCursorWithValueController(this.store, IdbCursorMeta meta) {
    this.meta = meta;
    init();
  }

  Cursor nextEvent(int index) {
    _SdbStoreCursorWithValue cursor = new _SdbStoreCursorWithValue(this, index);
    return cursor;
  }
}

class _SdbObjectStore extends ObjectStore {

  final IdbObjectStoreMeta meta;
  final _SdbTransaction transaction;
  _SdbDatabase get database => transaction.database;
  sdb.Database get sdbDatabase => database.db;
  sdb.Store sdbStore;


  _SdbObjectStore(this.transaction, this.meta) {
    sdbStore = sdbDatabase.getStore(name);
  }

  Future inWritableTransaction(Future computation()) {
    if (transaction.meta.mode != IDB_MODE_READ_WRITE) {
      return new Future.error(new DatabaseReadOnlyError());
    }
    return inTransaction(computation);
  }

  Future inTransaction(computation()) {
    return transaction.execute(computation);
//    transaction.txn

//    // create the transaction if needed
//    // make it async so that we get the result of the action before transaction completion
//    Completer completer = new Completer();
//    transaction._completed = completer.future;
//
//    return sdbStore.inTransaction(() {
//      return computation();
//    }).then((result) {
//      completer.complete();
//      return result;
//
//    })
//    return sdbStore.inTransaction(() {
//      return new Future.sync(computation).then((result) {
//
//      });
//    });
  }


  /// extract the key from the key itself or from the value
  /// it is a map and keyPath is not null
  dynamic _getKey(value, [key]) {

    if ((keyPath != null) && (value is Map)) {
      var keyInValue = value[keyPath];
      if (keyInValue != null) {
        if (key != null) {
          throw new ArgumentError("both key ${key} and inline keyPath ${keyInValue} are specified");
        } else {
          return keyInValue;
        }
      }
    }

    if (key == null && (!autoIncrement)) {
      throw new DatabaseError('neither keyPath nor autoIncrement set and trying to add object without key');
    }

    return key;
  }

  _put(value, key) {
    // Check all indexes
    List<Future> futures = [];
    if (value is Map) {

      meta.indecies.forEach((IdbIndexMeta indexMeta) {
        var fieldValue = value[indexMeta.keyPath];
        if (fieldValue != null) {
          sdb.Finder finder = new sdb.Finder(filter: new sdb.Filter.equal(indexMeta.keyPath, fieldValue), limit: 1);
          futures.add(sdbStore.findRecord(finder).then((sdb.Record record) {
            // not ourself
            if ((record != null) && (record.key != key) //
                && ((!indexMeta.multiEntry) && indexMeta.unique)) {
              throw new DatabaseError("key '${fieldValue}' already exists in ${record} for index ${indexMeta}");
            }
          }));
        }
      });

    }
    return Future.wait(futures).then((_) {
      return sdbStore.put(value, key);
    });
  }

  @override
  Future add(value, [key]) {
    return inWritableTransaction(() {
      return sdbStore.inTransaction(() {



        key = _getKey(value, key);

        if (key != null) {
          return sdbStore.get(key).then((existingValue) {
            if (existingValue != null) {
              throw new DatabaseError('Key ${key} already exists in the object store');
            }
            return _put(value, key);
          });
        } else {
          return _put(value, key);
        }
      });
    });
  }


  @override
  Future clear() {
    return inWritableTransaction(() {
      return sdbStore.clear();
    }).then((_) {
      return null;
    });
  }



  _storeKeyOrRangeFilter([key_OR_range]) {
    return _keyOrRangeFilter(sdb.Field.KEY, key_OR_range);
  }

  @override
  Future<int> count([key_OR_range]) {
    return inTransaction(() {
      return sdbStore.count(_storeKeyOrRangeFilter(key_OR_range));
    });
  }

  @override
  Index createIndex(String name, keyPath, {bool unique, bool multiEntry}) {
    IdbIndexMeta indexMeta = new IdbIndexMeta(name, keyPath, unique, multiEntry);
    meta.createIndex(database.meta, indexMeta);
    return new _SdbIndex(this, indexMeta);
  }

  @override
  Future delete(key) {
    return inWritableTransaction(() {
      return sdbStore.delete(key).then((_) {
        // delete returns null
        return null;
      });
    });
  }

  dynamic _recordToValue(sdb.Record record) {
    if (record == null) {
      return null;
    }
    var value = record.value;
    // Add key if _keyPath is not null
    if ((keyPath != null) && (value is Map)) {
      value[keyPath] = record.key;
    }

    return value;
  }

  @override
  Future getObject(key) {
    return inTransaction(() {
      return sdbStore.getRecord(key).then((sdb.Record record) {
        return _recordToValue(record);
      });
    });
  }

  @override
  Index index(String name) {
    IdbIndexMeta indexMeta = meta.index(name);
    return new _SdbIndex(this, indexMeta);
  }

  @override
  List<String> get indexNames => new List.from(meta.indexNames, growable: false);

  @override
  String get name => meta.name;

  sdb.SortOrder sortOrder(bool ascending) {
    return new sdb.SortOrder(keyField, ascending);
  }

  sdb.Filter cursorFilter(key, KeyRange range) {
    sdb.Filter filter;
    if (range != null) {
      return _keyRangeFilter(keyField, range);
    } else {
      return _keyFilter(keyField, key);

    }
  }

  String get keyField => keyPath != null ? keyPath : sdb.Field.KEY;

  @override
  Stream<CursorWithValue> openCursor({key, KeyRange range, String direction, bool autoAdvance}) {
    IdbCursorMeta cursorMeta = new IdbCursorMeta(key, range, direction, autoAdvance);
    _SdbStoreCursorWithValueController ctlr = new _SdbStoreCursorWithValueController(this, cursorMeta);

    inTransaction(() {
      return ctlr.openCursor();
    });

    return ctlr.stream;
  }

  @override
  Future put(value, [key]) {
    return inWritableTransaction(() {
      return _put(value, _getKey(value, key));
    });
  }

  @override
  bool get autoIncrement => meta.autoIncrement;

  @override
  get keyPath => meta.keyPath;
}

///
/// meta format
/// {"key":"version","value":1}
/// {"key":"stores","value":["test_store"]}
/// {"key":"store_test_store","value":{"name":"test_store","keyPath":"my_key","autoIncrement":true}}

class _SdbDatabase extends Database {

  static Logger logger = new Logger("SembastIdb");
  final bool LOGV = logger.isLoggable(Level.FINEST);

  _SdbTransaction versionChangeTransaction;
  final IdbDatabaseMeta meta = new IdbDatabaseMeta();
  final String _name;
  sdb.Database db;

  @override
  IdbSembastFactory get factory => super.factory;

  sdb.DatabaseFactory get sdbFactory => factory._databaseFactory;

  _SdbDatabase(IdbFactory factory, this._name) : super(factory);

  Future<List<IdbObjectStoreMeta>> _loadStoresMeta(List<String> storeNames) {
    List<String> keys = [];
    storeNames.forEach((String storeName) {
      keys.add("store_${storeName}");
    });
                    
    return db.mainStore.getRecords(keys).then((List<sdb.Record> records) {
      List<IdbObjectStoreMeta> list = [];
      records.forEach((sdb.Record record) {
        Map map = record.value;
        IdbObjectStoreMeta store = new IdbObjectStoreMeta.fromMap(map);
        list.add(store);
      });
      return list;
    });
  }
  
  Future open(int newVersion, void onUpgradeNeeded(VersionChangeEvent event)) {
    int previousVersion;
    _open() {
      return sdbFactory.openDatabase(join(factory._path, _name), version: 1).then((sdb.Database db) {
        this.db = db;
        return db.inTransaction(() {

          return db.mainStore.get("version").then((int version) {
            previousVersion = version;
          }).then((_) {
            // read meta
            return db.mainStore.getRecord("stores").then((sdb.Record record) {
              if (record != null) {
                // for now load all at once
                List<String> storeNames = record.value;
                return _loadStoresMeta(storeNames).then((List<IdbObjectStoreMeta> storeMetas) {
                  storeMetas.forEach((IdbObjectStoreMeta store) {
                    meta.addObjectStore(store);


                  });
                });
              }

            });
          });
        }).then((_) => db);



      });
    }

    return _open().then((db) {
      if (newVersion != previousVersion) {
        Set<IdbObjectStoreMeta> changedStores;

        meta.onUpgradeNeeded(() {
          versionChangeTransaction = new _SdbTransaction(this, meta.versionChangeTransaction);
          // could be null when opening an empty database
          if (onUpgradeNeeded != null) {
            onUpgradeNeeded(new _SdbVersionChangeEvent(this, previousVersion, newVersion));
          }
          changedStores = meta.versionChangeStores;
        });


        return db.inTransaction(() {

          return db.put(newVersion, "version").then((_) {
            if (changedStores.isNotEmpty) {
              return db.put(new List.from(objectStoreNames), "stores");
            }
          }).then((_) {
// write changes
            List<Future> futures = [];

            changedStores.forEach((IdbObjectStoreMeta storeMeta) {
              futures.add(db.put(storeMeta.toMap(), "store_${storeMeta.name}"));
            });

            return Future.wait(futures);

          });

        }).then((_) {
          // considered as opened
          meta.version = newVersion;
        });

      }
    });


  }

  @override
  void close() {
    db.close();
  }

  @override
  ObjectStore createObjectStore(String name, {String keyPath, bool autoIncrement}) {
    IdbObjectStoreMeta storeMeta = new IdbObjectStoreMeta(name, keyPath, autoIncrement);
    meta.createObjectStore(storeMeta);
    return new _SdbObjectStore(versionChangeTransaction, storeMeta);
  }

  @override
  void deleteObjectStore(String name) {
    throw 'not implemented yet';
  }

  @override
  String get name => _name;

  @override
  Iterable<String> get objectStoreNames {
    return meta.objectStoreNames;
  }

  @override
  Stream<VersionChangeEvent> get onVersionChange {
    throw 'not implemented yet';
  }

  @override
  Transaction transaction(storeName_OR_storeNames, String mode) {
    IdbTransactionMeta txnMeta = meta.transaction(storeName_OR_storeNames, mode);
    return new _SdbTransaction(this, txnMeta);
  }

  @override
  Transaction transactionList(List<String> storeNames, String mode) {
    IdbTransactionMeta txnMeta = meta.transaction(storeNames, mode);
    return new _SdbTransaction(this, txnMeta);
  }

  @override
  int get version => meta.version;

  Map toDebugMap() {
    Map map;
    if (meta != null) {
      map = meta.toDebugMap();
    } else {
      map = {};
    }

    if (db != null) {
      map["db"] = db.toDebugMap();
    }
    return map;
  }

  String toString() {
    return toDebugMap().toString();
  }
}
class IdbSembastFactory extends IdbFactory {

  final sdb.DatabaseFactory _databaseFactory;
  final String _path;

  @override
  bool get persistent => _databaseFactory.persistent;

  IdbSembastFactory(this._databaseFactory, this._path);

  String get name => IDB_FACTORY_SEMBAST;


  @override
  Future<Database> open(String dbName, {int version, OnUpgradeNeededFunction onUpgradeNeeded, OnBlockedFunction onBlocked}) {

    // check params
    if ((version == null) != (onUpgradeNeeded == null)) {
      return new Future.error(new ArgumentError('version and onUpgradeNeeded must be specified together'));
    }
    if (version == 0) {
      return new Future.error(new ArgumentError('version cannot be 0'));
    } else if (version == null) {
      version = 1;
    }

    // name null no
    if (dbName == null) {
      return new Future.error(new ArgumentError('name cannot be null'));
    }

    _SdbDatabase db = new _SdbDatabase(this, dbName);

    return db.open(version, onUpgradeNeeded).then((_) {
      return db;
    });

  }

  Future<IdbFactory> deleteDatabase(String dbName, {void onBlocked(Event)}) {
    if (dbName == null) {
      return new Future.error(new ArgumentError('dbName cannot be null'));
    }
    return _databaseFactory.deleteDatabase(join(_path, dbName));
  }

  @override
  bool get supportsDatabaseNames {
    return false;
  }

  Future<List<String>> getDatabaseNames() {
    return null;
  }
}
