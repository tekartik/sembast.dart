library sembast.memory;

import 'dart:async';
import 'sembast.dart';
import 'src/sembast_fs.dart';

//import 'package:tekartik_core/dev_utils.dart';

/// In memory implementation
class MemoryDatabaseFactory implements DatabaseFactory {
  @override
  Future<Database> openDatabase(String path,
      {int version,
      OnVersionChangedFunction onVersionChanged,
      DatabaseMode mode}) {
    Database db;
    if (path == null) {
      db = _defaultDatabase;
    } else {
      db = _databases[path];
    }

    if (db == null) {
      db = new Database(new _MemoryDatabaseStorage(this, path));
    }

    return db
        .open(version: version, onVersionChanged: onVersionChanged, mode: mode)
        .then((Database db) {
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

  @override
  bool get hasStorage => false;
}

final MemoryDatabaseFactory memoryDatabaseFactory =
    new MemoryDatabaseFactory._();

///
/// Open a new database in memory
///
Future<Database> openMemoryDatabase() {
  return memoryDatabaseFactory.openDatabase(null);
}

class _MemoryDatabaseStorage extends DatabaseStorage {
  final MemoryDatabaseFactory factory;
  final String path;
  _MemoryDatabaseStorage(this.factory, this.path);

  @override
  Future<bool> find() {
    return new Future.value(factory._databases[path] != null);
  }

  @override
  Future findOrCreate() => new Future.value();

  @override
  bool get supported => false;

  @override
  Future delete() => null;

  Stream<String> readLines() => null;

  @override
  Future appendLines(List<String> lines) => null;

  @override
  DatabaseStorage get tmpStorage => null;

  @override
  Future tmpRecover() => null;
}
