library tekartik_iodb.database;

import 'dart:async';
import 'dart:io';
import 'dart:convert';
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
  List<SortOrder> sortOrders;
  set sortOrder(SortOrder sortOrder) {
    sortOrders = [sortOrder];
  }
  bool match(Record record) {
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
  Map<dynamic, Record> _records = new Map();

  Store._(this.database, this.name);

  Future put(var value, [var key]) {
    return database.inTransaction(() {
      Record record = new Record._(null, _encodeKey(key), _encodeValue(value), false);

      return _putRecord(record).then((_) {
        return key;
      });
    });

  }

  Future<List<Record>> findRecords(Finder finder) {
    return inTransaction(() {
      List<Record> result = [];
      _records.values.forEach((Record record) {
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

  Future inTransaction(Future action()) {
    return database.inTransaction(action);
  }
  Future<Record> putRecord(Record record) {
    return database.inTransaction(() {
      return _putRecord(record).then((_) {
        return record;
      });
    });
  }

  Future putRecords(List<Record> records) {
    return inTransaction(() {

      return _putRecords(records);
    });
  }

  Future<Record> _putRecord(Record record) {
    return _putRecords([record]);
  }

  Future _putRecords(List<Record> records) {

    IOSink sink = database._file.openWrite(mode: FileMode.APPEND);

    // writable record
    for (Record record in records) {
      sink.writeln(JSON.encode(record._toMap()));
    }
    return sink.close().then((_) {
      // save in memory
      for (Record record in records) {
        // remove deleted
        if (record.deleted) {
          _records.remove(record.key);
        } else {
          // add inserted/updated
          _records[record.key] = record;
        }

      }
      return records;
    });


  }

  Future<Record> getRecord(var key) {
    return inTransaction(() {
      return _records[key];
    });
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
      Record record = _records[key];
      if (record == null) {
        return null;
      } else {
        record._deleted = true;
        return _putRecord(record).then((_) {
          return key;
        });
      }
    });
  }

  bool _has(var key) {
    return _records.containsKey(key);
  }
}

class Database {

  String _path;
  int _rev = 0;

  _Meta _meta;
  String get path => _path;
  int get version => _meta.version;

  bool _opened = false;
  File _file;

  Store get mainStore => _mainStore;

  Store _mainStore;
  Map<String, Store> _stores = new Map();

  /**
   * only valid before open
   */
  static Future deleteDatabase(String path) {
    return new File(path).exists().then((exists) {
      return new File(path).delete(recursive: true).catchError((_) {
      });
    });
  }

  Database();

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

  Completer currentTransactionCompleter;

  Future inTransaction(Future action()) {

    if ((currentTransactionCompleter == null) || (currentTransactionCompleter.isCompleted)) {
      currentTransactionCompleter = new Completer();
    } else {
      return currentTransactionCompleter.future.then((_) {
        return inTransaction(action);
      });
    }
    Completer actionCompleter = currentTransactionCompleter;

    return new Future.sync(action).then((result) {
      actionCompleter.complete();
      return result;
    });
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

  _loadRecord(Record record) {
    if (record.deleted) {
      record.store._records.remove(record.key);
    } else {
      record.store._records[record.key] = record;
    }
  }

  /**
   * reload from file system
   */
  Future reOpen() {
    String path = this.path;
    close();
    return open(path);
  }

  Store getStore(String storeName) {
    Store store;
    if (storeName == null) {
      store = _mainStore;
    } else {
      store = _stores[storeName];
      if (store == null) {
        store = new Store._(this, storeName);
        _stores[storeName] = store;
      }

    }
    return store;
  }

  Future open(String path, [int version]) {
    if (_opened) {
      return new Future.value();
    }
    _Meta meta;
    File file;
    return FileSystemEntity.isFile(path).then((isFile) {
      if (!isFile) {
        return new File(path).create(recursive: true).then((File file) {

        }).catchError((e) {
          return FileSystemEntity.isFile(path).then((isFile) {
            if (!isFile) {
              throw e;
            }
          });
        });
      }
    }).then((_) {
      file = new File(path);

      _mainStore = new Store._(this, _main_store);
      bool needCompact = false;
      return file.openRead().transform(UTF8.decoder).transform(new LineSplitter()).forEach((String line) {
        // everything is JSON
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


      }).then((_) {
        if (meta == null) {
          // devError("$e $st");
          // no version yet

          // if no version asked this is a read-only view only
          if (version == null) {
            throw "not a database";
          }
          meta = new _Meta(version);
          IOSink sink = file.openWrite(mode: FileMode.WRITE);


          sink.writeln(JSON.encode(meta.toMap()));
          return sink.close();
        } else {
          if (needCompact) {
            //TODO rewrite
          }
        }
      });
    }).then((_) {
      _file = file;
      _path = path;
      _meta = meta;
      _opened = true;

      // upgrade?
      if (version == null) {

      }
    }).catchError((e, st) {
      //devPrint("$e $st");
      throw e;
    });

  }

  void close() {
    _opened = false;
    _mainStore = null;
    _path = null;
    _meta = null;
    // return new Future.value();
  }
}
