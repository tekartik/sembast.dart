library sembast.memory;

import 'dart:async';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/storage.dart';
import 'sembast.dart';
import 'src/sembast_fs.dart';
import 'src/memory/memory_file_system.dart';

/// The pure memory factory
final MemoryDatabaseFactory memoryDatabaseFactory =
    new MemoryDatabaseFactory._();

/// The memory with a simulated file system factory
final MemoryFsDatabaseFactory memoryFsDatabaseFactory =
    new MemoryFsDatabaseFactory();

/// In memory implementation
class MemoryDatabaseFactory implements DatabaseFactory {
  @override
  Future<Database> openDatabase(String path,
      {int version,
      OnVersionChangedFunction onVersionChanged,
      DatabaseMode mode}) async {
    SembastDatabase db;
    if (path != null) {
      db = _databases[path];
    }

    if (db == null) {
      db = new SembastDatabase(new _MemoryDatabaseStorage(this, path));
    }

    await db.open(
        version: version, onVersionChanged: onVersionChanged, mode: mode);

    if (path != null) {
      _databases[path] = db;
    }
    return db;
  }

  // make it private
  MemoryDatabaseFactory._();

  @override
  Future deleteDatabase(String path) {
    if (path != null) {
      _databases.remove(path);
    }
    return new Future.value();
  }

  //Database _defaultDatabase;
  Map<String, SembastDatabase> _databases = new Map();

  @override
  bool get hasStorage => false;
}

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

/// The simulated fs factory class
class MemoryFsDatabaseFactory extends FsDatabaseFactory {
  MemoryFsDatabaseFactory() : super(memoryFileSystem);
}
