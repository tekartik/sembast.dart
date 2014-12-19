library sembast;

//import 'package:tekartik_core/dev_utils.dart';
import 'package:logging/logging.dart';
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

  bool get persistent;

  ///
  /// Open a new of existing database
  ///
  /// [path] is the location of the database
  /// [version] is the version expected, if not null and if the existing version is different, onVersionChanged is called
  /// [mode] is [DatabaseMode.CREATE] by default
  ///
  Future<Database> openDatabase(String path, {int version, OnVersionChangedFunction onVersionChanged, DatabaseMode mode});

  ///
  /// Delete a database if existing
  ///
  Future deleteDatabase(String path);

  //Stream<String> getData(String path);
}

/// Storage implementation
abstract class DatabaseStorage {
  String get path;
  bool get supported;
  DatabaseStorage();

  DatabaseStorage get tmpStorage;
  Future tmpRecover();
  Future delete();
  Future<bool> find();
  Future findOrCreate();

  Stream<String> readLines();
  Future appendLines(List<String> lines);
  Future appendLine(String line) => appendLines([line]);
}

/// Exceptions
class DatabaseException implements Exception {

  static int BAD_PARAM = 0;
  static int DATABASE_NOT_FOUND = 1;
  final int _code;
  final String _message;
  int get code => _code;
  String get message => _message;
  DatabaseException.badParam(this._message) : _code = BAD_PARAM;
  DatabaseException.databaseNotFound(this._message) : _code = DATABASE_NOT_FOUND;

  String toString() => "[${_code}] ${_message}";
}

//import 'package:tekartik_core/dev_utils.dart';

const String _db_version = "version";
const String _db_sembast_version = "sembast";
const String _record_key = "key";
const String _store_name = "store";
const String _record_value = "value"; // only for simple type where the key is not a string
const String _record_deleted = "deleted"; // boolean

const String _main_store = "_main"; // main store name;
class _Meta {

  int version;
  int sembastVersion = 1;

  _Meta.fromMap(Map map) {
    version = map[_db_version];
    sembastVersion = map[_db_sembast_version];
  }

  static bool isMapMeta(Map map) {
    return map[_db_version] != null;
  }

  _Meta(this.version);

  Map toMap() {
    var map = {
      _db_version: version,
      _db_sembast_version: sembastVersion
    };
    return map;
  }

  @override
  String toString() {
    return toMap().toString();
  }
}

///
/// Database transaction
///
class Transaction {

  final int id;

  // make the completer async as the Transaction following
  // action is not a priority
  Completer _completer = new Completer();
  Transaction._(this.id);

  bool get isCompleted => _completer.isCompleted;
  Future get completed => _completer.future;

  @override
  String toString() {
    return "txn ${id}${_completer.isCompleted ? ' completed' : ''}";
  }
}

///
/// Special field access
///
class Field {
  static String VALUE = "_value";
  static String KEY = "_key";
}

///
/// Records
///
class Record {

  get key => _key;
  get value => _value;
  bool get deleted => _deleted == true;
  Store get store => _store;

  final Store _store;
  var _key; // not final as can be set during auto key generation
  final _value;
  bool _deleted;

  operator [](var field) {
    if (field == Field.VALUE) {
      return value;
    } else if (field == Field.KEY) {
      return key;
    }
    return value[field];
  }

  Record._fromMap(Database db, Map map)
      : _store = db.getStore(map[_store_name]),
        _key = map[_record_key],
        _value = map[_record_value],
        _deleted = map[_record_deleted] == true;

  Record _clone() {
    return new Record._(_store, _key, _value, _deleted);
  }

  static bool isMapRecord(Map map) {
    var key = map[_record_key];
    return (key != null);
  }

  Record._(this._store, var key, var _value, [this._deleted])
      : _key = _cloneKey(key),
        _value = _cloneValue(_value);

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

  Record(this._store, this._value, [this._key]) : _deleted = null;


  @override
  int get hashCode => key == null ? 0 : key.hashCode;

  operator ==(o) {
    if (o is Record) {
      return key == null ? false : (key == o.key);
    }
    return false;
  }
}

_cloneKey(var key) {
  if (key is String) {
    return key;
  }
  if (key is int) {
    return key;
  }
  if (key == null) {
    return key;
  }
  throw "key ${key} not supported${key != null ? 'type:${key.runtimeType}' : ''}";
}

_cloneValue(var value) {
  if (value is Map) {
    return new Map.from(value);
  }
  if (value is List) {
    return new List.from(value);
  }
  if (value is String) {
    return value;
  }
  if (value is num) {
    return value;
  }
  if (value == null) {
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
    if (!super.match(record)) {
      return false;
    }

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

class _ByKeyFilter extends Filter {
  var key;

  _ByKeyFilter(this.key) : super._();
  @override
  bool match(Record record) {
    if (!super.match(record)) {
      return false;
    }
    return record.key == key;
  }

  @override
  String toString() {
    return "${Field.KEY} = ${key}";
  }
}

class _FilterPredicate extends Filter {
  String field;
  _FilterOperation operation;
  var value;
  _FilterPredicate(this.field, this.operation, this.value) : super._();

  @override
  bool match(Record record) {
    if (!super.match(record)) {
      return false;
    }

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

  Map toDebugMap() {
    return {
      field: ascending ? "asc" : "desc"
    };
  }

  @override
  String toString() {
    return "${field} ${ascending ? 'asc' : 'desc'}";
  }
}

abstract class Filter {
  static bool marchRecord(Filter filter, Record record) {
    if (filter != null) {
      return filter.match(record);
    } else {
      return (!record.deleted);
    }
  }

  bool match(Record record) {
    if (record.deleted) {
      return false;
    }
    return true;
  }

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
  factory Filter.byKey(key) => new _ByKeyFilter(key);

}

class Finder {
  Filter filter;
  int offset;
  int limit;

  Finder({this.filter, this.sortOrders, this.limit, this.offset});
  List<SortOrder> sortOrders = [];
  set sortOrder(SortOrder sortOrder) {
    sortOrders = [sortOrder];
  }
//  bool match(Record record) {
//    if (record.deleted) {
//      return false;
//    }
//    if (filter != null) {
//      return filter.match(record);
//    }
//    return true;
//  }
  int compare(Record record1, Record record2) {
    int result = 0;
    if (sortOrders != null) {
      for (SortOrder order in sortOrders) {
        result = order.compare(record1, record2);
        // stop as soon as they differ
        if (result != 0) {
          break;
        }
      }
    }

    return result;
  }

  Finder clone({int limit}) {
    return new Finder(filter: filter, sortOrders: sortOrders, //
    limit: limit == null ? this.limit : limit, //
    offset: offset);
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
      if (database.LOGV) {
        Database.logger.fine("${database.transaction} put ${record}");
      }
      return record.key;
    });

  }

  _forEachRecords(Filter filter, void action(Record record)) {
// handle record in transaction first
    if (_inTransaction && _txnRecords != null) {
      _txnRecords.values.forEach((Record record) {
        if (Filter.marchRecord(filter, record)) {
          action(record);
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
      if (Filter.marchRecord(filter, record)) {
        action(record);
      }

    });
  }

  Future<Record> findRecord(Finder finder) {
    if (finder.limit != 1) {
      finder = finder.clone(limit: 1);
    }
    return findRecords(finder).then((List<Record> records) {
      if (records.isNotEmpty) {
        return records.first;
      }
      return null;
    });
  }

  Future<List<Record>> findRecords(Finder finder) {
    return inTransaction(() {
      List<Record> result;


      result = [];

      _forEachRecords(finder.filter, (Record record) {
        result.add(record);
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
      Store store = record.store;

      // auto-gen key if needed
      if (record.key == null) {
        record._key = ++store._lastIntKey;
      } else {
        // update last int key in case auto gen is needed again
        if (record._key is int && record.key > store._lastIntKey) {
          store._lastIntKey = record.key;
        }
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
    if (database.LOGV) {
      Database.logger.fine("${database.transaction} get ${record} key ${key}");
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

  Future<int> count([Filter filter]) {
    return inTransaction(() {
      int count = 0;
      _forEachRecords(filter, (Record record) {
        count++;
      });
      return count;
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
  Future deleteAll(Iterable keys) {
    return inTransaction(() {
      List<Record> updates = [];
      List deletedKeys = [];
      for (var key in keys) {
        Record record = _getRecord(key);
        if (record != null) {
          Record clone = record._clone();
          clone._deleted = true;
          updates.add(clone);
          deletedKeys.add(key);
        }
      }

      if (updates.isNotEmpty) {
        _putRecords(updates);
      }
      return deletedKeys;
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

  ///
  /// TODO: decide on return value
  ///
  Future clear() {
    return inTransaction(() {
      // first delete the one in transaction
      return new Future.sync(() {
        if (_txnRecords != null) {
          return deleteAll(new List.from(_txnRecords.keys, growable: false));
        }
      }).then((_) {
        Iterable keys = _records.keys;
        return deleteAll(new List.from(keys, growable: false));
      });
    });
  }
}

class Database {

  static Logger logger = new Logger("Sembast");
  final bool LOGV = logger.isLoggable(Level.FINEST);

  final DatabaseStorage _storage;

  String get path => _storage.path;

  //int _rev = 0;
  // incremental for each transaction
  int _txnId = 0;
  Map<int, Transaction> _transactions = new Map();

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

  int get _currentZoneTxnId => Zone.current[_zoneTransactionKey];
  bool get _inTransaction => _currentZoneTxnId != null;
  ///
  /// get the current zone transaction
  ///
  Transaction get transaction {
    int txnId = _currentZoneTxnId;
    if (txnId == null) {
      return null;
    } else {
      return _transactions[_currentZoneTxnId];
    }
  }

  // for transaction
  static const _zoneTransactionKey = "sembast.txn"; // transaction key
  //static const _zoneChildKey = "sembast.txn.child"; // bool

  Future newTransaction(action()) {
    if (!_inTransaction) {
      return inTransaction(action);
    }
    Transaction txn = transaction;
    return txn.completed.then((_) {
      return newTransaction(action);
    });
  }
  Future inTransaction(action()) {

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

      Transaction txn = new Transaction._(++_txnId);
      _transactions[txn.id] = txn;

      var result;
      var err;
      runZoned(() {
        // execute and commit
        if (LOGV) {
          logger.fine("begin transaction");
        }
        return new Future.sync(action).then((_result) {
          return new Future.sync(_commit).then((_) {
            result = _result;
            if (LOGV) {
              logger.fine("commit transaction");
            }
          });

        }).catchError((e, st) {
          logger.severe("txn error $e");
          logger.finest(e);
          logger.finest(st);
          //txn._completer.completeError(e);
          err = e;
          //return new Future.error(e);
          _transactions.remove(txn.id);
          _clearTxnData();
          txn._completer.complete();
          actionCompleter.completeError(err);
        });
      }, zoneValues: {
        _zoneTransactionKey: txn.id
      }, onError: (e, st) {
        logger.severe("txn zone error $e");
        logger.finest(e);
        logger.finest(st);
        //txn._completer.completeError(e);
        err = e;
        //return new Future.error(e);
        _transactions.remove(txn.id);
        _clearTxnData();
        txn._completer.complete();
        actionCompleter.completeError(err);

      }).whenComplete(() {
        if (!actionCompleter.isCompleted) {
          _transactions.remove(txn.id);
          _clearTxnData();
          actionCompleter.complete(result);
          txn._completer.complete();
        }


      });
      return actionCompleter.future;

    } else {
      return new Future.sync(action);
//      if (LOGV) {
//        logger.fine("inTxn ${transaction} start");
//      }
//      // in child transaction
//      // no commit yet
//      if ((_txnChildCompleter == null) || (_txnChildCompleter.isCompleted)) {
//        _txnChildCompleter = new Completer();
//      } else {
//        return _txnChildCompleter.future.then((_) {
//          return inTransaction(action);
//        });
//      }
//
//      Completer actionCompleter = _txnChildCompleter;
//
//      _done() {
//        if (LOGV) {
//          logger.fine("inTxn ${transaction} done");
//        }
//        actionCompleter.complete();
//      }
//      devPrint("inner ${transaction}");
//      return runZoned(() {
//        return new Future.sync(action);
//      }, zoneValues: {
//        _zoneChildKey: true
//      }, onError: (e, st) {
//        print("$e");
//        print("$st");
//        _done();
//        devPrint("inner ${transaction} error");
//      }).whenComplete(() {
//        _done();
//        devPrint("inner ${transaction} done");
//
//      });

    }


  }

  _setRecordInMemory(Record record) {
    record.store._setRecordInMemory(record);
  }
  _loadRecord(Record record) {
    record.store._loadRecord(record);
  }

  ///
  /// Compact the database (work in progress)
  ///
  ///
  @deprecated
  Future compact() {
    return newTransaction(() {
      if (_storage.supported) {
        DatabaseStorage tmpStorage = _storage.tmpStorage;
        return tmpStorage.delete().then((_) {
          return tmpStorage.findOrCreate().then((_) {
            List<String> lines = [];
            lines.add(JSON.encode(_meta.toMap()));
            stores.forEach((Store store) {
              store._records.values.forEach((Record record) {
                Map map = record._toMap();
                var encoded;
                try {
                  encoded = JSON.encode(map);
                } catch (e, st) {
                  print(map);
                  print(e);
                  print(st);
                  rethrow;
                }
                lines.add(encoded);
              });
            });
            tmpStorage.appendLines(lines);

          });
        }).then((_) {
          return _storage.tmpRecover();
        });
      }
    });
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
          Map map = record._toMap();
          var encoded;
          try {
            encoded = JSON.encode(map);
          } catch (e, st) {
            print(map);
            print(e);
            print(st);
            rethrow;
          }
          lines.add(encoded);
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
  Future reOpen({int version, OnVersionChangedFunction onVersionChanged, DatabaseMode mode}) {
    close();
    return open(version: version, onVersionChanged: onVersionChanged, mode: mode);
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

  ///
  /// find existing store
  ///
  Store findStore(String storeName) {
    Store store;
    if (storeName == null) {
      store = _mainStore;
    } else {
      store = _stores[storeName];
    }
    return store;
  }

  ///
  /// get or create a store
  ///
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

  Future deleteStore(String storeName) {
    Store store = findStore(storeName);
    if (store == null) {
      return new Future.value();
    } else {
      return store.clear().then((_) {
        // do not delete main
        if (store != mainStore) {
          _stores.remove(storeName);
        }
      });
    }
  }

  Future open({int version, OnVersionChangedFunction onVersionChanged, DatabaseMode mode}) {
    if (_opened) {
      if (path != this.path) {
        throw new DatabaseException.badParam("existing path ${this.path} differ from open path ${path}");
      }
      return new Future.value(this);
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
      Future _findOrCreate() {
        if (mode == DatabaseMode.EXISTING) {
          return _storage.find().then((bool found) {
            if (!found) {
              throw new DatabaseException.databaseNotFound("Database (open existing only) ${path} not found");
            }
          });
        } else {
          return _storage.findOrCreate();
        }
      }

      return _findOrCreate().then((_) {
        if (_storage.supported) {
          // empty stores
          _mainStore = null;
          _stores = new Map();
          _checkMainStore();




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


          }).then((_) => _openDone());
        } else {
          // ensure main store exists
          // but do not erase previous data
          _checkMainStore();
          meta = _meta;
          return _openDone();
        }
      });
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

  Map toDebugMap() {
    return {
      "path": path,
      "version": version,
      "stores": _stores
    };
  }

  @override
  String toString() {
    return toDebugMap().toString();
  }
}
