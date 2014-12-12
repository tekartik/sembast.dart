library tekartik_iodb.database_memory;

import 'dart:async';
import 'database.dart';
//import 'package:tekartik_core/dev_utils.dart';

/// In memory implementation
class MemoryDatabaseFactory implements DatabaseFactory {
  @override
  Future<Database> openDatabase(String path, {int version, OnVersionChangedFunction onVersionChanged, DatabaseMode mode}) {
    Database db;
    if (path == null) {
      db = _defaultDatabase;
    } else {
      db = _databases[path];
    }

    if (db == null) {
      db = new Database(new _MemoryDatabaseStorage(path));

    }

    return db.open(version: version, onVersionChanged: onVersionChanged, mode: mode).then((Database db) {
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
  
  bool get persistent => false;
}

final MemoryDatabaseFactory memoryDatabaseFactory = new MemoryDatabaseFactory._();

///
/// Open a new database in memory
///
Future<Database> openMemoryDatabase() {
  return memoryDatabaseFactory.openDatabase(null);
}

class _MemoryDatabaseStorage extends DatabaseStorage {
  static Database _defaultDatabase;
  static Map<String, Database> _databases = new Map();

  String path;
  _MemoryDatabaseStorage(this.path);

  @override
  bool get supported => false;

  @override
  Future delete() => null;

  @override
  Future findOrCreate() => null;

  Stream<String> readLines() => null;

  @override
  Future appendLines(List<String> lines) => null;
}
