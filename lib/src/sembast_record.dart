part of sembast;


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

  ///
  /// allow overriding store to clean for main store
  ///
  Record _clone({Store store}) {
    return new Record._(store == null ? _store : store, _key, _value, _deleted);
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
