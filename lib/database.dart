library tekartik_iodb.database;

import 'dart:async';
import 'dart:convert';

/// can return a future or not
typedef OnVersionChangedFunction(Database db, int oldVersion, int newVersion);

///
/// The modes in which a Database can be opened.
///
class DatabaseMode {
  /// The default mode
  /// The database is created if not found
  /// This is the default
  static const CREATE = const DatabaseMode._internal(0);
  /// The mode for opening an existing database
  static const EXISTING = const DatabaseMode._internal(1);
  /// The mode for emptying the existing content if any
  static const EMPTY = const DatabaseMode._internal(2);
  final int _mode;

  const DatabaseMode._internal(this._mode);
}

abstract class DatabaseFactory {
  ///
  /// Open a new of existing database
  ///
  /// [path] is the location of the database
  /// [version] is the version expected, if not null and if the existing version is different, onVersionChanged is called
  /// [mode] is [DatabaseMode.CREATE] by default
  ///
  Future<Database> openDatabase(String path, {int version, OnVersionChangedFunction onVersionChanged, DatabaseMode mode});

  Future deleteDatabase(String path);

  //Stream<String> getData(String path);
}

/// Storage implementation
abstract class DatabaseStorage {
  String get path;
  bool get supported;
  DatabaseStorage();

  Future delete();
  Future findOrCreate();

  Stream<String> readLines();
  Future appendLines(List<String> lines);
  Future appendLine(String line) => appendLines([line]);
}

/// Exceptions
class DatabaseException implements Exception {

  static int BAD_PARAM = 0;
  final int _code;
  final String _messsage;
  int get code => _code;
  String get message => _messsage;
  DatabaseException.badParam(this._messsage) : _code = BAD_PARAM;

  String toString() => "[${_code}] ${_messsage}";
}

//import 'package:tekartik_core/dev_utils.dart';

const String _db_version = "version";
const String _record_key = "key";
const String _store_name = "store";
const String _record_value = "value"; // only for simple type where the key is not a string
const String _record_deleted = "deleted"; // boolean

const String _main_store = "_main"; // main store name;
class _Meta {

  int version;

  _Meta.fromMap(Map map) {
    version = map[_db_version];
  }

  static bool isMapMeta(Map map) {
    return map[_db_version] != null;
  }

  _Meta(this.version);

  Map toMap() {
    var map = {
      _db_version: version
    };
    return map;
  }

  @override
  String toString() {
    return toMap().toString();
  }
}

/**
 * Special field access
 */
class Field {
  static String VALUE = "_value";
  static String KEY = "_key";
}

class Record {

  get key => _key;
  get value => _value;
  bool get deleted => _deleted == true;
  Store get store => _store;

  Store _store;
  var _key;
  var _value;
  bool _deleted;

  operator [](var field) {
    if (field == Field.VALUE) {
      return value;
    } else if (field == Field.KEY) {
      return key;
    }
    return value[field];
  }

  Record._fromMap(Database db, Map map) {
    _store = db.getStore(map[_store_name]);
    _key = map[_record_key];
    _value = map[_record_value];
    _deleted = map[_record_deleted] == true;
  }

  Record _clone() {
    return new Record._(_store, _key, _value, _deleted);
  }

  static bool isMapRecord(Map map) {
    var key = map[_record_key];
    return (key != null);
  }

  Record._(this._store, this._key, this._value, [this._deleted]);

  Map _toBaseMap() {
    Map map = {};
    map[_record_key] = key;

    if (deleted == true) {
      map[_record_deleted] = true;
    }
    if (store != null && store.name != _main_store) {
      map[_store_name] = store.name;
    }
    return map;
  }

  Map _toMap() {

    Map map = _toBaseMap();
    map[_record_value] = value;
    return map;


  }


  @override
  String toString() {
    return _toMap().toString();
  }

  Record(this._store, this._value, [this._key]);


  @override
  int get hashCode => key == null ? 0 : key.hashCode;

  operator ==(o) {
    if (o is Record) {
      return key == null ? false : (key == o.key);
    }
    return false;
  }
}
_encodeKey(var key) {
  if (key is String) {
    return key;
  }
  if (key is int) {
    return key;
  }
  throw "key ${key} not supported${key != null ? 'type:${key.runtimeType}' : ''}";
}

_encodeValue(var value) {
  if (value is Map) {
    return value;
  }
  if (value is String) {
    return value;
  }
  if (value is num) {
    return value;
  }
  throw "value ${value} not supported${value != null ? 'type:${value.runtimeType}' : ''}";
}


class _CompositeFilter extends Filter {
  bool isAnd; // if false it is OR
  bool get isOr => !isAnd;
  List<Filter> filters;

  _CompositeFilter.or(this.filters)
      : super._(),
        isAnd = false;
  _CompositeFilter.and(this.filters)
      : super._(),
        isAnd = true;

  @override
  bool match(Record record) {

    for (Filter filter in filters) {
      if (filter.match(record)) {
        if (isOr) {
          return true;
        }
      } else {
        if (isAnd) {
          return false;
        }
      }
    }
    // if isOr, nothing has matches so far
    return isAnd;
  }

  @override
  String toString() {
    return filters.join(' ${isAnd ? "AND" : "OR" } ');
  }
}
class _FilterOperation {
  final int value;
  const _FilterOperation._(this.value);
  static const _FilterOperation EQUAL = const _FilterOperation._(1);
  static const _FilterOperation NOT_EQUAL = const _FilterOperation._(2);
  static const _FilterOperation LESS_THAN = const _FilterOperation._(3);
  static const _FilterOperation LESS_THAN_OR_EQUAL = const _FilterOperation._(4);
  static const _FilterOperation GREATER_THAN = const _FilterOperation._(5);
  static const _FilterOperation GREATER_THAN_OR_EQUAL = const _FilterOperation._(6);
  static const _FilterOperation IN = const _FilterOperation._(7);
  @override
  String toString() {
    switch (this) {
      case _FilterOperation.EQUAL:
        return "=";
      case _FilterOperation.NOT_EQUAL:
        return "!=";
      case _FilterOperation.LESS_THAN:
        return "<";
      case _FilterOperation.LESS_THAN_OR_EQUAL:
        return "<=";
      case _FilterOperation.GREATER_THAN:
        return ">";
      case _FilterOperation.GREATER_THAN_OR_EQUAL:
        return ">=";
      case _FilterOperation.IN:
        return "IN";
      default:
        throw "${this} not supported";
    }
  }

}

class _FilterPredicate extends Filter {
  String field;
  _FilterOperation operation;
  var value;
  _FilterPredicate(this.field, this.operation, this.value) : super._();

  bool match(Record record) {
    switch (operation) {
      case _FilterOperation.EQUAL:
        return record[field] == value;
      case _FilterOperation.NOT_EQUAL:
        return record[field] != value;
      case _FilterOperation.LESS_THAN:
        return Comparable.compare(record[field], value) < 0;
      case _FilterOperation.LESS_THAN_OR_EQUAL:
        return Comparable.compare(record[field], value) <= 0;
      case _FilterOperation.GREATER_THAN:
        return Comparable.compare(record[field], value) > 0;
      case _FilterOperation.GREATER_THAN_OR_EQUAL:
        return Comparable.compare(record[field], value) >= 0;
      case _FilterOperation.IN:
        return (value as List).contains(record[field]);
      default:
        throw "${this} not supported";
    }
  }

  @override
  String toString() {
    return "${field} ${operation} ${value}";
  }
}

class SortOrder {
  final bool ascending;
  final String field;

  SortOrder(this.field, bool ascending) : ascending = ascending == true;
  int compare(Record record1, Record record2) {
    int result = compareAscending(record1, record2);
    return ascending ? result : -result;
  }
  int compareAscending(Record record1, Record record2) {
    var value1 = record1[field];
    var value2 = record2[field];
    if (value1 == null) {
      return -1;
    } else if (value2 == null) {
      return 1;
    }
    return value1.compareTo(value2);
  }
}

abstract class Filter {
  bool match(Record record);

  Filter._();
  factory Filter.equal(String field, value) {
    return new _FilterPredicate(field, _FilterOperation.EQUAL, value);
  }
  factory Filter.notEqual(String field, value) {
    return new _FilterPredicate(field, _FilterOperation.NOT_EQUAL, value);
  }
  factory Filter.lessThan(String field, value) {
    return new _FilterPredicate(field, _FilterOperation.LESS_THAN, value);
  }
  factory Filter.lessThanOrEquals(String field, value) {
    return new _FilterPredicate(field, _FilterOperation.LESS_THAN_OR_EQUAL, value);
  }
  factory Filter.greaterThan(String field, value) {
    return new _FilterPredicate(field, _FilterOperation.GREATER_THAN, value);
  }
  factory Filter.greaterThanOrEquals(String field, value) {
    return new _FilterPredicate(field, _FilterOperation.GREATER_THAN_OR_EQUAL, value);
  }
  factory Filter.inList(String field, List value) {
    return new _FilterPredicate(field, _FilterOperation.IN, value);
  }

  factory Filter.or(List<Filter> filters) => new _CompositeFilter.or(filters);
  factory Filter.and(List<Filter> filters) => new _CompositeFilter.and(filters);

}

class Finder {
  Filter filter;
  List<SortOrder> sortOrders = [];
  set sortOrder(SortOrder sortOrder) {
    sortOrders = [sortOrder];
  }
  bool match(Record record) {
    if (record.deleted) {
      return false;
    }
    if (filter != null) {
      return filter.match(record);
    }
    return true;
  }
  int compare(Record record1, Record record2) {
    int result = 0;
    for (SortOrder order in sortOrders) {
      result = order.compare(record1, record2);
      // stop as soon as they differ
      if (result != 0) {
        break;
      }
    }

    return result;
  }

  @override
  String toString() {
    return "filter: ${filter}, sort: ${sortOrders}";
  }
}
class Store {
  final Database database;
  final String name;
  // for key generation
  int _lastIntKey = 0;

  Map<dynamic, Record> _records = new Map();
  Map<dynamic, Record> _txnRecords;

  bool get _inTransaction => database._inTransaction;

  Store._(this.database, this.name);

  Future put(var value, [var key]) {
    return database.inTransaction(() {
      Record record = new Record._(this, key, value, false);

      _putRecord(record);
      return record.key;
    });

  }

  Future<List<Record>> findRecords(Finder finder) {
    return inTransaction(() {
      List<Record> result = [];

      // handle record in transaction first
      if (_inTransaction && _txnRecords != null) {
        _txnRecords.values.forEach((Record record) {
          if (finder.match(record)) {
            result.add(record);
          }
        });
      }

      // then the regular unless already in transaction
      _records.values.forEach((Record record) {

        if (_inTransaction && _txnRecords != null) {
          if (_txnRecords.keys.contains(record.key)) {
            // already handled
            return;
          }
        }
        if (finder.match(record)) {
          result.add(record);
        }
      });

      // sort
      result.sort((Record record1, record2) {
        return finder.compare(record1, record2);

      });
      return result;
    });
  }

  _setRecordInMemory(Record record) {
    if (record.deleted) {
      record.store._records.remove(record.key);
    } else {
      record.store._records[record.key] = record;
    }
  }


  _loadRecord(Record record) {
    var key = record.key;
    _setRecordInMemory(record);
    // update for auto increment
    if (key is int) {
      if (key > _lastIntKey) {
        _lastIntKey = key;
      }
    }
  }

  Future inTransaction(Future action()) {
    return database.inTransaction(action);
  }
  Future<Record> putRecord(Record record) {
    return database.inTransaction(() {
      return _putRecord(record._clone());
    });
  }

  Future<List<Record>> putRecords(List<Record> records) {
    return inTransaction(() {

      List<Record> clones = [];
      for (Record record in records) {
        clones.add(record._clone());
      }
      return _putRecords(clones);
    });
  }

  Record _putRecord(Record record) {
    return _putRecords([record]).first;
  }

  // record must have been clone before
  List<Record> _putRecords(List<Record> records) {

    if (_txnRecords == null) {
      _txnRecords = new Map();
    }

    // temp records
    for (Record record in records) {
      // auto-gen key if needed
      if (record.key == null) {
        record._key = ++record.store._lastIntKey;
      }

      _txnRecords[record.key] = record;
      ;
    }
    return records;



  }


  Record _getRecord(var key) {
    var record;

    // look in current transaction
    if (_inTransaction) {
      if (_txnRecords != null) {
        record = _txnRecords[key];
      }
    }

    if (record == null) {
      record = _records[key];
    }
    return record;
  }

  Future<Record> getRecord(var key) {
    Record record = _getRecord(key);
    if (record != null) {
      if (record.deleted) {
        record = null;
      }
    }
    return new Future.value(record);
  }

  Future<List<Record>> getRecords(List keys) {
    List<Record> records = [];

    for (var key in keys) {
      Record record = _getRecord(key);
      if (record != null) {
        if (!record.deleted) {
          records.add(record);
          ;
        }
      }

    }
    return new Future.value(records);
  }

  Future get(var key) {
    return getRecord(key).then((Record record) {
      if (record != null) {
        return record.value;
      }
      return null;
    });
  }

  Future<int> count() {
    return inTransaction(() {
      return _records.length;
    });
  }

  Future delete(var key) {
    return inTransaction(() {
      Record record = _getRecord(key);
      if (record == null) {
        return null;
      } else {
        // clone to keep the existing as is
        Record clone = record._clone();
        clone._deleted = true;
        _putRecord(clone);
        return key;
      }
    });
  }

  /// return the list of deleted keys
  Future deleteAll(List keys) {
    return inTransaction(() {
      List<Record> updates = [];
      List updatedKeys = [];
      for (var key in keys) {
        Record record = _getRecord(key);
        if (record != null) {
          Record clone = record._clone();
          clone._deleted = true;
          updates.add(clone);
          updatedKeys.add(key);
        }
      }

      if (updates.isNotEmpty) {
        _putRecords(updates);
      }
      return updatedKeys;
    });
  }

  bool _has(var key) {
    return _records.containsKey(key);
  }

  void _rollback() {
    // clear map;
    _txnRecords = null;
  }

  @override
  String toString() {
    return "${name}";
  }
}

class Database {

  final DatabaseStorage _storage;

  String get path => _storage.path;

  int _rev = 0;

  _Meta _meta;
  int get version => _meta.version;

  bool _opened = false;

  Store get mainStore => _mainStore;

  Store _mainStore;
  Map<String, Store> _stores = new Map();

  Iterable<Store> get stores => _stores.values;

  Database([this._storage]);

  Future onUpgrade(int oldVersion, int newVersion) {
    // default is to clear everything
    return new Future.value();
  }

  Future onDowngrade(int oldVersion, int newVersion) {
    // default is to clear everything
    return new Future.value();
  }

  Future put(var value, [var key]) {
    return _mainStore.put(value, key);
  }

  void _clearTxnData() {
// remove temp data in all store
    for (Store store in stores) {
      store._rollback();
    }
  }
  void rollback() {
    // only valid in a transaction
    if (!_inTransaction) {
      throw new Exception("not in transaction");
    }
    _clearTxnData();

  }

  Completer _txnRootCompleter;
  Completer _txnChildCompleter;

  bool get _inTransaction => Zone.current[_zoneRootKey] == true;
  // for transaction
  static const _zoneRootKey = "tekartik.iodb";
  static const _zoneChildKey = "tekartik.iodb.child";

  Future inTransaction(Future action()) {

    //devPrint("z: ${Zone.current[_zoneRootKey]}");
    //devPrint("z: ${Zone.current[_zoneChildKey]}");

    // not in transaction yet
    if (!_inTransaction) {
      if ((_txnRootCompleter == null) || (_txnRootCompleter.isCompleted)) {
        _txnRootCompleter = new Completer();
      } else {
        return _txnRootCompleter.future.then((_) {
          return inTransaction(action);
        });
      }

      Completer actionCompleter = _txnRootCompleter;

      return runZoned(() {
        // execute and commit
        return new Future.sync(action).then((result) {
          return new Future.sync(_commit).then((_) {
            return result;
          });

        });
      }, zoneValues: {
        _zoneRootKey: true
      }).whenComplete(() {
        _clearTxnData();
        actionCompleter.complete();
      });
    } else {
      // in child transaction
      // no commit yet
      if ((_txnChildCompleter == null) || (_txnChildCompleter.isCompleted)) {
        _txnChildCompleter = new Completer();
      } else {
        return _txnChildCompleter.future.then((_) {
          return inTransaction(action);
        });
      }

      Completer actionCompleter = _txnChildCompleter;

      return runZoned(() {
        return new Future.sync(action);
      }, zoneValues: {
        _zoneChildKey: true
      }).whenComplete(() {
        actionCompleter.complete();

      });

    }


  }

  _setRecordInMemory(Record record) {
    record.store._setRecordInMemory(record);
  }
  _loadRecord(Record record) {
    record.store._loadRecord(record);
  }

  // future or not
  _commit() {

    List<Record> txnRecords = [];
    for (Store store in stores) {
      if (store._txnRecords != null) {

        txnRecords.addAll(store._txnRecords.values);
      }
    }

    // end of commit
    _saveInMemory() {
      for (Record record in txnRecords) {
        _setRecordInMemory(record);
      }
    }
    if (_storage.supported) {
      if (txnRecords.isNotEmpty) {
        List<String> lines = [];

        // writable record
        for (Record record in txnRecords) {
          lines.add(JSON.encode(record._toMap()));
        }
        return _storage.appendLines(lines).then((_) {
          _saveInMemory();
        });
      }
    } else {
      _saveInMemory();
    }
  }

  Future<Record> putRecord(Record record) {
    return record.store.put(record);
  }

  Future get(var key) {
    return _mainStore.get(key);
  }

  Future<int> count() {
    return _mainStore.count();
  }

  Future delete(var key) {
    return _mainStore.delete(key);
  }

  bool _hasRecord(Record record) {
    return record.store._has(record.key);
  }


  /**
   * reload from file system
   */
  Future reOpen() {
    close();
    return open();
  }

  void _checkMainStore() {
    if (_mainStore == null) {
      _addStore(null);
    }
  }
  Store _addStore(String storeName) {

    if (storeName == null) {
      return _mainStore = _addStore(_main_store);
    } else {
      Store store = new Store._(this, storeName);
      _stores[storeName] = store;
      return store;
    }
  }

  Store getStore(String storeName) {
    Store store;
    if (storeName == null) {
      store = _mainStore;
    } else {
      store = _stores[storeName];
      if (store == null) {
        store = _addStore(storeName);
      }

    }
    return store;
  }

//  Future open2({int version}) {
//    if (_opened) {
//          // TODO check version
//          //  throw new DatabaseException.badParam("existing path ${_path} differ from open path ${path}");
//          return new Future.value();
//        }
//    factory.loadLines(_path).
//  }
  Future open({int version, OnVersionChangedFunction onVersionChanged, DatabaseMode mode}) {
    if (_opened) {
      if (path != this.path) {
        throw new DatabaseException.badParam("existing path ${this.path} differ from open path ${path}");
      }
      return new Future.value();
    }
    return runZoned(() {


      _Meta meta;

      Future _handleVersionChanged(int oldVersion, int newVersion) {
        var result;
        if (onVersionChanged != null) {
          result = onVersionChanged(this, oldVersion, newVersion);
        }

        return new Future.value(result).then((_) {
          meta = new _Meta(newVersion);

          if (_storage.supported) {
            return _storage.appendLine(JSON.encode(meta.toMap()));
          }
        });
      }

      Future _openDone() {
        // make sure mainStore is created
        _checkMainStore();

        // Set current meta
        // so that it is an old value during onVersionChanged
        if (meta == null) {
          meta = new _Meta(0);
        }
        if (_meta == null) {
          _meta = meta;
        }
        
        bool needVersionChanged = false;

        int oldVersion = meta.version;
        
        if (oldVersion == 0) {
          needVersionChanged = true;

          // Make version 1 by default
          if (version == null) {
            version = 1;
          }
          meta = new _Meta(version);
        } else {
          // no specific version requested or same
          if ((version != null) && (version != oldVersion)) {
            needVersionChanged = true;
          }
        }

        // mark it opened
        _opened = true;

        if (needVersionChanged) {
          return _handleVersionChanged(oldVersion, version).then((_) {
            _meta = meta;
            return this;
          });
        } else {
          _meta = meta;
          return new Future.value(this);
        }
      }

      //_path = path;


      if (_storage.supported) {
        // empty stores
        _mainStore = null;
        _stores = new Map();
        _checkMainStore();

        return _storage.findOrCreate().then((_) {

//          _mainStore = new Store._(this, _main_store);
//          _stores[_main_store] = _mainStore;

          bool needCompact = false;


          return _storage.readLines().forEach((String line) {
            // evesrything is JSON
            Map map = JSON.decode(line);


            if (_Meta.isMapMeta(map)) {
              // meta?
              meta = new _Meta.fromMap(map);
            } else if (Record.isMapRecord(map)) {
              // record?
              Record record = new Record._fromMap(this, map);
              if (_hasRecord(record)) {
                needCompact = true;
              }
              _loadRecord(record);

            }


          });
        }).then((_) => _openDone());
      } else {
        // ensure main store exists
        // but do not erase previous data
        _checkMainStore();
        meta = _meta;
        return _openDone();
      }
    }).catchError((e, st) {
      //devPrint("$e $st");
      throw e;
    });
  }



  void close() {
    _opened = false;
    //_mainStore = null;
    //_meta = null;
    // return new Future.value();
  }
}