import 'package:sembast/sembast.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/record.dart';
import 'package:sembast/src/sembast_impl.dart';
import 'package:sembast/src/database.dart';
import 'package:sembast/src/utils.dart';

class SembastRecord implements Record {
  @override
  dynamic key;

  @override
  get value => _value;

  @override
  bool get deleted => _deleted == true;

  set deleted(bool deleted) => _deleted = deleted;

  @override
  Store get store => _store;

  final Store _store;
  var _value;
  bool _deleted;

  ///
  /// get the value of the specified [field]
  ///
  @override
  operator [](String field) {
    if (field == Field.value) {
      return value;
    } else if (field == Field.key) {
      return key;
    } else {
      return value[field];
    }
  }

  set value(value) => _value = sanitizeValue(value);

  ///
  /// set the [value] of the specified [field]
  ///
  @override
  void operator []=(String field, var value) {
    if (field == Field.value) {
      this.value = value;
    } else if (field == Field.key) {
      key = value;
    } else {
      _value[field] = value;
    }
  }

  SembastRecord.fromMap(Database db, Map map)
      : _store =
            (db as SembastDatabase).getStore(map[dbStoreNameKey] as String),
        key = map[dbRecordKey],
        _value = sanitizeValue(map[dbRecordValueKey]),
        _deleted = map[dbRecordDeletedKey] == true;

  ///
  /// allow overriding store to clean for main store
  ///
  Record clone({Store store}) {
    return new SembastRecord.copy(
        store == null ? _store : store, key, _value, _deleted);
  }

  ///
  /// check whether the map specified looks like a record
  ///
  static bool isMapRecord(Map map) {
    var key = map[dbRecordKey];
    return (key != null);
  }

  SembastRecord.copy(this._store, var key, var _value, [this._deleted])
      : key = _cloneKey(key),
        _value = _cloneValue(_value);

  Map _toBaseMap() {
    Map map = {};
    map[dbRecordKey] = key;

    if (deleted == true) {
      map[dbRecordDeletedKey] = true;
    }
    if (store != null && store.name != dbMainStore) {
      map[dbStoreNameKey] = store.name;
    }
    return map;
  }

// The actual map written to disk
  Map toMap() {
    Map map = _toBaseMap();
    map[dbRecordValueKey] = value;
    return map;
  }

  @override
  String toString() {
    return toMap().toString();
  }

  ///
  /// Create a record in a given [store] with a given [value] and
  /// an optional [key]
  ///
  SembastRecord(Store store, dynamic value, [dynamic key])
      : this._store = store,
        this._value = value,
        this.key = key;

  @override
  int get hashCode => key == null ? 0 : key.hashCode;

  @override
  bool operator ==(o) {
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
  if (key is num) {
    return key;
  }
  if (key == null) {
    return key;
  }
  throw new DatabaseException.badParam("key ${key} not supported${key != null
      ? ' type:${key.runtimeType}'
      : ''}");
}

_cloneValue(var value) {
  if (value is Map) {
    return new Map.from(value).cast<String, dynamic>();
  }
  if (value is List) {
    return new List.from(value);
  }
  if (value is String) {
    return value;
  }
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value;
  }
  if (value == null) {
    return value;
  }
  throw new DatabaseException.badParam(
      "value ${value} not supported${value != null ? ' type:${value
          .runtimeType}' : ''}");
}
