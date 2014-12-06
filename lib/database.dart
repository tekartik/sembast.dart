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

class Field {
  static String VALUE = _record_value;
}

class Record {
  _RecordImpl _recordImpl;

  get key => _recordImpl.key;
  get value => _recordImpl.value;
  bool get deleted => _recordImpl.deleted == true;
  Store get store => _recordImpl.store;
  operator [](var field) => _recordImpl[field];

  Record(Store store, var value, [var key]) {
    _recordImpl = new _RecordImpl(store, key, value);

  }
  Record._(this._recordImpl);

  @override
  String toString() {
    return _recordImpl.toString();
  }

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

class _RecordImpl {
  Store store;
  var key;
  var value;
  bool deleted;

  operator [](var field) {
    if (field == _record_value) {
      return value;
    }
    return value[field];
  }

  _RecordImpl._fromMap(Database db, Map map) {
    store = db.getStore(map[_store_name]);
    key = map[_record_key];
    value = map[_record_value];
    deleted = map[_record_deleted] == true;
  }

  static bool isMapRecord(Map map) {
    var key = map[_record_key];
    return (key != null);
  }

  _RecordImpl(this.store, this.key, this.value, [this.deleted]);

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

  Map toMap() {

    Map map = _toBaseMap();
    map[_record_value] = value;
    return map;


  }


  @override
  String toString() {
    return toMap().toString();
  }
}

class CompositeFilter extends Filter {
  bool isAnd; // if false it is OR
  bool get isOr => !isAnd;
  List<Filter> filters;

  CompositeFilter.or(this.filters)
      : super._(),
        isAnd = false;
  CompositeFilter.and(this.filters)
      : super._(),
        isAnd = false;

  @override
  bool match(_RecordImpl recordImpl) {

    for (Filter filter in filters) {
      if (filter.match(recordImpl)) {
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
}
class FilterOperation {
  final int value;
  const FilterOperation._(this.value);
  static const FilterOperation EQUAL = const FilterOperation._(1);
  static const FilterOperation NOT_EQUAL = const FilterOperation._(2);
  static const FilterOperation LESS_THAN = const FilterOperation._(3);
  static const FilterOperation LESS_THAN_OR_EQUAL = const FilterOperation._(4);
  static const FilterOperation GREATER_THAN = const FilterOperation._(5);
  static const FilterOperation GREATER_THAN_OR_EQUAL = const FilterOperation._(6);
  static const FilterOperation IN = const FilterOperation._(7);

}

class FilterPredicate extends Filter {
  String field;
  FilterOperation operation;
  var value;
  FilterPredicate(this.field, this.operation, this.value) : super._();

  bool match(_RecordImpl recordImpl) {
    switch (operation) {
      case FilterOperation.EQUAL:
        return recordImpl[field] == value;
      case FilterOperation.NOT_EQUAL:
        return recordImpl[field] != value;
      case FilterOperation.LESS_THAN:
        return Comparable.compare(recordImpl[field], value) < 0;
      case FilterOperation.LESS_THAN_OR_EQUAL:
        return Comparable.compare(recordImpl[field], value) <= 0;
      case FilterOperation.GREATER_THAN:
        return Comparable.compare(recordImpl[field], value) > 0;
      case FilterOperation.GREATER_THAN_OR_EQUAL:
        return Comparable.compare(recordImpl[field], value) >= 0;
      case FilterOperation.IN:
        return (value as List).contains(recordImpl[field]);
      default:
        throw "${this} not supported";
    }
  }
}

class SortOrder {
  final bool ascending;
  final String field;

  SortOrder(this.field, bool ascending) : ascending = ascending == true;
  int compare(_RecordImpl record1, _RecordImpl record2) {
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
  bool match(_RecordImpl recordImpl);

  Filter._();
  factory Filter.equal(String field, value) {
    return new FilterPredicate(field, FilterOperation.EQUAL, value);
  }
  factory Filter.inList(String field, List value) {
    return new FilterPredicate(field, FilterOperation.IN, value);
  }

}

class Finder {
  Filter filter;
  SortOrder sortOrder;
  bool match(_RecordImpl recordImpl) {
    if (filter != null) {
      return filter.match(recordImpl);
    }
    return true;
  }
  int compare(_RecordImpl record1, _RecordImpl record2) {
    if (sortOrder != null) {
      return sortOrder.compare(record1, record2);
    }
    return 0;
  }
}
class Store {
  final Database database;
  final _StoreImpl _store;
  String get name => _store.name;
  Store._(this.database, this._store);
  Map<dynamic, _RecordImpl> get _records => _store.records;

  Future put(var value, [var key]) {
    return database.inTransaction(() {
      _RecordImpl record = new _RecordImpl(null, _encodeKey(key), _encodeValue(value), false);

      return _putRecord(record).then((_) {
        return key;
      });
    });

  }

  Future<List<Record>> findRecords(Finder finder) {
    return inTransaction(() {
      List<Record> result = [];
      _records.values.forEach((_RecordImpl recordImpl) {
        if (finder.match(recordImpl)) {
          result.add(new Record._(recordImpl));
        }
      });
      // sort
//      result.sort((Record record1, record2) {
//        return finder.compare(record1, record2);
//
//      });
      return result;
    });
  }

  Future inTransaction(Future action()) {
    return database.inTransaction(action);
  }
  Future<Record> putRecord(Record record) {
    return database.inTransaction(() {
      return _putRecord(record._recordImpl).then((_) {
        return record;
      });
    });
  }

  Future putRecords(List<Record> records) {
    return inTransaction(() {

      return _putRecords(records);
    });
  }

  Future<_RecordImpl> _putRecord(_RecordImpl record) {

    IOSink sink = database._file.openWrite(mode: FileMode.APPEND);

    // writable record
    sink.writeln(JSON.encode(record.toMap()));
    return sink.close().then((_) {
      // save in memory
      _records[record.key] = record;
      return record;
    });


  }

  Future _putRecords(List<Record> records) {

    IOSink sink = database._file.openWrite(mode: FileMode.APPEND);

    // writable record
    for (Record record in records) {
      sink.writeln(JSON.encode(record._recordImpl.toMap()));
    }
    return sink.close().then((_) {
      // save in memory
      for (Record record in records) {
        _records[record.key] = record._recordImpl;
      }
      return records;
    });


  }

  Future<Record> getRecord(var key) {
    _RecordImpl record = _records[key];
    if (record == null) {
      return null;
    }
    return new Future.value(new Record._(record));
  }

  Future get(var key) {
    _RecordImpl record = _records[key];
    var value = record == null ? null : record.value;
    return new Future.value(value);
  }

  Future<int> count() {
    int value = _records.length;
    return new Future.value(value);
  }

  Future delete(var key) {
    _RecordImpl record = _records[key];
    if (record == null) {
      return new Future.value(null);
    } else {
      IOSink sink = database._file.openWrite(mode: FileMode.APPEND);

      // write deleted record
      record.deleted = true;
      sink.writeln(JSON.encode(record.toMap()));
      return sink.close().then((_) {
        // save in memory
        _records.remove(key);
        return key;
      });
    }
  }
}

class _StoreImpl {
  final String name;
  _StoreImpl._(this.name);
  Map<dynamic, _RecordImpl> records = new Map();
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

  bool _hasRecord(_RecordImpl record) {
    return record.store._records.containsKey(record.key);
  }

  _loadRecord(_RecordImpl record) {
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
        store = new Store._(this, new _StoreImpl._(storeName));
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
    _StoreImpl mainStore;
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

      _mainStore = new Store._(this, new _StoreImpl._(_main_store));
      bool needCompact = false;
      return file.openRead().transform(UTF8.decoder).transform(new LineSplitter()).forEach((String line) {
        // everything is JSON
        Map map = JSON.decode(line);


        if (_Meta.isMapMeta(map)) {
          // meta?
          meta = new _Meta.fromMap(map);
        } else if (_RecordImpl.isMapRecord(map)) {
          // record?
          _RecordImpl record = new _RecordImpl._fromMap(this, map);
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
