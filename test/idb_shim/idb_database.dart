library sembast.idb_database;

import 'package:tekartik_core/dev_utils.dart';
import 'package:logging/logging.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:idb_shim/idb_client.dart';
import 'package:sembast/database.dart' as sdb;
import 'dart:async';
import 'package:path/path.dart';
import 'idb_common_meta.dart';

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

  //
  // Create or execute the transaction
  // leaving a time to breath
  //
  Future execute(action()) {

    _execute(i) {
      //devPrint("exec $i");
      Completer completer = completers[i];
      Function action = actions[i];
      return new Future.sync(action).then((result) {
        //devPrint("done $i");
        completer.complete(result);
      }).catchError((e) {
        //devPrint(" err $i");
        completer.completeError(e);
      });
    }


    _next() {
      //devPrint('_next? ${index}/${actions.length}');
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

    if (sdbTransaction == null) {
      sdbTransaction = sdbDatabase.transaction;
      if (sdbTransaction == null) {
        return sdbDatabase.inTransaction(() {

          // assign right away as this is tested
          sdbTransaction = sdbDatabase.transaction;

          var finalResult = action();
          var result = finalResult;




          _next();
          return finalResult;


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

      }
    }
    // not lazy
    Completer completer = new Completer.sync();
    completers.add(completer);
    actions.add(action);
    devPrint("push ${actions.length}");
    _next();
    return completer.future.then((result) {
      // re-push termination check
    });
  }

  sdb.Transaction sdbTransaction;
  List<Completer> completers = [];
  List<Function> actions = [];

  final IdbTransactionMeta meta;
  _SdbTransaction(_SdbDatabase database, this.meta) : super(database);

  @override
  Future<Database> get completed => sdbTransaction == null ? new Future.value(database) : sdbTransaction.completed;

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
    throw 'not implemented yet';
  }

  @override
  Stream<Cursor> openKeyCursor({key, KeyRange range, String direction, bool autoAdvance}) {
    throw 'not implemented yet';
  }

  @override
  bool get unique => meta.unique;
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

abstract class IdbCursor {
  //
  // Idb redefinition
  //
  String get direction;
  void advance(int count);
  Future delete();
  void next();
  Object get primaryKey;
  Object get key;
  Future update(value);
  Object get value;
}

abstract class _SdbCursorMixin implements IdbCursor {
  // set upon creation
  int index;
  _SdbCursorController ctlr;

  _SdbObjectStore get store => ctlr.store;
  IdbCursorMeta get meta => ctlr.meta;

  sdb.Record get record => ctlr.records[index];
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

  //TODO for index
  @override
  Object get key => record.key;


  @override
  Object get primaryKey => record.key;

  @override
  Future update(value) => store.put(value, key);

  // TODO: implement value
  @override
  Object get value => record.value;
}
class _SdbCursorWithValue extends CursorWithValue with _SdbCursorMixin {
  //
  // Sdb specific implementation
  //



  //


  IdbCursorMeta get meta => ctlr.meta;

  _SdbCursorWithValue(_SdbCursorController ctlr, int index) {
    this.ctlr = ctlr;
    this.index = index;
  }






}

class _SdbCursorController {
  final IdbCursorMeta meta;
  final _SdbObjectStore store;
  List<sdb.Record> records;
  bool get done => currentIndex == null;
  int currentIndex = -1;
  StreamController ctlr;

  Stream<CursorWithValue> get stream => ctlr.stream;
  _SdbCursorController(this.store, this.meta) {
    ctlr = new StreamController(sync: true);
  }

  Future autoNext() {
    return advance(1).then((_) {
      if (meta.autoAdvance && (!done)) {
        autoNext();
      }
    });
  }


  Future advance(int count) {
    currentIndex += count;
    if (currentIndex >= records.length) {
      currentIndex = null;
      return ctlr.close();
    }
    _SdbCursorWithValue cwv = new _SdbCursorWithValue(this, currentIndex);
    ctlr.add(cwv);
    return new Future.value();

  }

  openCursor() {

    sdb.Filter filter = store._cursorFilter(meta.key, meta.range);
    sdb.SortOrder sortOrder = new sdb.SortOrder(store.keyField, meta.ascending);
    sdb.Finder finder = new sdb.Finder(filter: filter, sortOrders: [sortOrder]);
    return store.sdbStore.findRecords(finder).then((List<sdb.Record> records) {
      this.records = records;
      autoNext();
    });
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
            if (record != null && record.key != key && !indexMeta.multiEntry) {
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
    meta.createIndex(indexMeta);
    return new _SdbIndex(this, indexMeta);
  }

  @override
  Future delete(key) {
    return inWritableTransaction(() {
      return sdbStore.delete(key);
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

  sdb.Filter _cursorFilter(key, KeyRange range) {
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
    _SdbCursorController ctlr = new _SdbCursorController(this, cursorMeta);

    inTransaction(() {
      ctlr.openCursor();
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

  Logger logger = new Logger("SembastIdb");

  _SdbTransaction versionChangeTransaction;
  final IdbDatabaseMeta meta = new IdbDatabaseMeta();
  final String _name;
  sdb.Database db;

  @override
  IdbSembastFactory get factory => super.factory;

  sdb.DatabaseFactory get sdbFactory => factory._databaseFactory;

  _SdbDatabase(IdbFactory factory, this._name) : super(factory);

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
                List<String> storeNames = record.value;
                List<String> keys = [];
                storeNames.forEach((String storeName) {
                  keys.add("store_${storeName}");
                });
                return db.mainStore.getRecords(keys).then((List<sdb.Record> records) {
                  records.forEach((sdb.Record record) {
                    Map map = record.value;
                    IdbObjectStoreMeta store = new IdbObjectStoreMeta.fromMap(meta, map);
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
    IdbObjectStoreMeta storeMeta = new IdbObjectStoreMeta(meta, name, keyPath, autoIncrement);
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
