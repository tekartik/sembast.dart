library tekartik_iodb.database_memory;

import 'dart:async';

import 'database.dart';
//import 'package:tekartik_core/dev_utils.dart';

/// In memory implementation
class MemoryDatabaseFactory implements DatabaseFactory {
  @override
  Future<Database> openDatabase(String path, {int version, OnVersionChangedFunction onVersionChanged, DatabaseMode mode}) {
    _MemoryDatabase db;
    if (path == null) {
      db = _defaultDatabase;
    } else {
      db = _databases[path];
    }

    if (db == null) {
      db = new _MemoryDatabase(path);

    }

    return db._open(version, onVersionChanged, mode).then((_MemoryDatabase db) {
      if (path == null) {
        _defaultDatabase = db;
      } else {
        _databases[path] = db;
      }
      return db;

    });

  }

  // make it private
  MemoryDatabaseFactory._();

  @override
  Future deleteDatabase(String path) {
    if (path == null) {
      _defaultDatabase = null;
    } else {
      _databases.remove(path);
    }
    return new Future.value();
  }

  Database _defaultDatabase;
  Map<String, Database> _databases = new Map();
}

final MemoryDatabaseFactory memoryDatabaseFactory = new MemoryDatabaseFactory._();

///
/// Open a new database in memory
///
Future<Database> openMemoryDatabase() {
  return memoryDatabaseFactory.openDatabase(null);
}

class _MemoryDatabase extends Database {

  String _path;
  int _version;

  @override
  int get version => _version;

  @override
  String get path => _path;

  @override
  Future<_MemoryDatabase> reOpen() {
    return new Future.value(this);
  }

  bool _opened = false;
  _MemoryDatabase(this._path);

  Future<_MemoryDatabase> _open(int version, OnVersionChangedFunction onVersionChanged, DatabaseMode mode) {
    if (_opened) {
//        if (path != _path) {
//          throw new DatabaseException.badParam("existing path ${_path} differ from open path ${path}");
//        }
      return new Future.value(this);
    } else {
      //devPrint("todo");
      _version = version;
      return new Future.value(this);
    }


  }
}
