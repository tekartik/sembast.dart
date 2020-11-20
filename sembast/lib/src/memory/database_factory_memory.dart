import 'dart:async';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/database_factory_mixin.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/jdb/jdb_factory_memory.dart';
import 'package:sembast/src/memory/file_system_memory.dart';
import 'package:sembast/src/sembast_fs.dart';
import 'package:sembast/src/sembast_jdb.dart';
import 'package:sembast/src/storage.dart';

/// The pure memory factory
final DatabaseFactoryMemory databaseFactoryMemory = DatabaseFactoryMemory();

/// The memory with a simulated file system factory
final DatabaseFactoryMemoryFs databaseFactoryMemoryFs =
    DatabaseFactoryMemoryFs();

/// The memory with a simulated jdb factory
final DatabaseFactoryMemoryJdb databaseFactoryMemoryJdb =
    DatabaseFactoryMemoryJdb();

/// In memory implementation
class DatabaseFactoryMemory extends SembastDatabaseFactory
    with DatabaseFactoryMixin {
  @override
  Future doDeleteDatabase(String path) async {
    if (path != null) {
      _databases.remove(path);
      _exists.remove(path);
    }
  }

  //Database _defaultDatabase;
  // True when the database exists
  final _exists = <String, bool>{};
  final _databases = <String, SembastDatabase>{};

  @override
  bool get hasStorage => false;

  @override
  SembastDatabase newDatabase(DatabaseOpenHelper openHelper) {
    SembastDatabase? db;
    var path = openHelper.path;
    // For null path we always create a new database
    if (path != null) {
      db = _databases[path];
    }

    if (db == null) {
      db = SembastDatabase(openHelper, DatabaseStorageMemory(this, path));
      if (path != null) {
        _databases[path] = db;
      }
    }
    return db;
  }
}

///
/// Open a new database in memory
///
Future<Database> openMemoryDatabase() {
  return databaseFactoryMemory.openDatabase(null);
}

/// In memory storage.
class DatabaseStorageMemory extends DatabaseStorage {
  /// The factory.
  final DatabaseFactoryMemory factory;
  @override
  final String path;

  /// In memory storage.
  DatabaseStorageMemory(this.factory, this.path);

  @override
  Future<bool> find() {
    return Future.value(factory._exists[path] == true);
  }

  @override
  Future findOrCreate() async {
    // Always create
    factory._exists[path] = true;
  }

  @override
  bool get supported => false;

  @override
  Future delete() => null;

  @override
  Stream<String> readLines() => null;

  @override
  Future appendLines(List<String> lines) => null;

  @override
  DatabaseStorage? get tmpStorage => null;

  @override
  Future tmpRecover() => null;

  @override
  Stream<String> readSafeLines() {
    throw UnimplementedError();
  }
}

/// The simulated fs factory class
class DatabaseFactoryMemoryFs extends DatabaseFactoryFs {
  /// In memory fs.
  DatabaseFactoryMemoryFs() : super(fileSystemMemory);
}

/// The simulated jdb factory class
class DatabaseFactoryMemoryJdb extends DatabaseFactoryJdb {
  /// In memory fs.
  DatabaseFactoryMemoryJdb() : super(jdbFactoryMemory);
}
