library tekartik_iodb.database;

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:tekartik_core/dev_utils.dart';

const String _db_version = "version";
const String _record_key = "_key";
const String _store_key = "_store";
const String _record_value = "_value"; // only for simple type where the key is not a string

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

class Record {
  _Record _record;
  @override
  String toString() {
    return _record.toString();
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

class _Record {
  var key;
  int rev;
  var value;

  _Record.fromMap(Map map) {
    key = map[_record_key];

    // It is a simple key/value object
    // if the key is null or if there is only 1 value
    // to handle the case when key is not null
    if ((key == null) || (map.length == 1)) {
      key = map.keys.first;
      value = map.values.first;
    } else {
      var value = map[_record_value];
      if (value != null) {
        this.value = value;
      } else {
        this.value = new Map();
        map.forEach((k, v) {
          this.value[k] = v;
        });
      }
    }
  }

  static bool _isSimpleRecord(key, map) {
    return (key == null) || (map.length == 1);
  }
  static bool isMapRecord(Map map) {
    var key = map[_record_key];
    if (key == null) {
      return map.length == 1;
    }
    return true;
  }

  _Record(this.key, this.rev, this.value) {
    
  }
  Map toMap() {

    if (value is Map) {
      // put the key in
      value[_record_key] = key;
      return value;
    } else if (!(key is String)) {
      Map map = {
        _record_key: key,
        _record_value: value
      };
      return map;

    } else {

      Map map = {
        key: value
      };
      return map;
    }


  }

  @override
  String toString() {
    return toMap().toString();
  }
}

class _Store {
  String name;
  Map<dynamic, _Record> records = new Map();
}

class Database {

  String _path;
  int _rev = 0;

  _Meta _meta;
  String get path => _path;
  int get version => _meta.version;

  bool _opened = false;
  File _file;

  _Store _mainStore;
  Map<String, _Store> _stores;

  /**
   * only valid before open
   */
  static Future delete(String path) {
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
    if (value is Map) {
      
    }
    _Record _record = new _Record(_encodeKey(key), ++_rev, _encodeValue(value));


    IOSink sink = _file.openWrite(mode: FileMode.APPEND);
    
    // writable record
    sink.writeln(JSON.encode(_record.toMap()));
    return sink.close().then((_) {
      // save in memory
      _mainStore.records[key] = _record;
      return key;
    });

  }

  Future inTransaction(Future action()) {
    return action();
  }
  
  Future get(var key) {
    _Record record = _mainStore.records[key];
    var value = record == null ? null : record.value;
    return new Future.value(value);
  }

  _loadRecord(_Store store, _Record record) {
    store.records[record.key] = record;
  }

  /**
   * reload from file system
   */
  Future reOpen() {
    String path = this.path;
    close();
    return open(path);
  }

  Future open(String path, [int version]) {
    if (_opened) {
      return new Future.value();
    }
    _Meta meta;
    File file;
    _Store mainStore;
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

      mainStore = new _Store();
      return file.openRead().transform(UTF8.decoder).transform(new LineSplitter()).forEach((String line) {
        // everything is JSON
        Map map = JSON.decode(line);


        if (_Meta.isMapMeta(map)) {
          // meta?
          meta = new _Meta.fromMap(map);
        } else if (_Record.isMapRecord(map)) {
          // record?
          _Record record = new _Record.fromMap(map);
          _loadRecord(mainStore, record);

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
        }
      });
    }).then((_) {
      _mainStore = mainStore;
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
