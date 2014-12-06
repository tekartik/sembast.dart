library tekartik_iodb.database;

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:tekartik_core/dev_utils.dart';

class _Meta {

  int version;

  _Meta.fromMap(Map map) {
    version = map["version"];
  }

  static bool isMapMeta(Map map) {
    return map["version"] != null;
  }

  _Meta(this.version);

  Map toMap() {
    var map = {
      "version": version
    };
    return map;
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

  _Record.fromMap(Map json) {
    key = json["key"];
    rev = json["rev"];
    value = json["value"];
  }

  static bool isMapRecord(Map map) {
    return map["key"] != null;
  }

  _Record(this.key, this.rev, this.value);
  Map toMap() {
    Map map = {
      "key": _encodeKey(key),
      "rev": rev,
      "value": _encodeValue(value)
    };
    return map;
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
    _Record _record = new _Record(_encodeKey(key), ++_rev, _encodeValue(value));


    IOSink sink = _file.openWrite(mode: FileMode.APPEND);
    sink.writeln(JSON.encode(_record.toMap()));
    return sink.close().then((_) {
      // save in memory
      _mainStore.records[key] = _record;
      return key;
    });

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
