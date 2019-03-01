import 'dart:async';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:synchronized/synchronized.dart';

class DatabaseOpenOptions {
  final int version;
  final OnVersionChangedFunction onVersionChanged;
  final DatabaseMode mode;
  final SembastCodec codec;

  DatabaseOpenOptions({
    this.version,
    this.onVersionChanged,
    this.mode,
    this.codec,
  });

  @override
  String toString() {
    var map = <String, dynamic>{};
    if (version != null) {
      map['version'] = version;
    }
    if (mode != null) {
      map['mode'] = mode;
    }
    if (codec != null) {
      map['codec'] = codec;
    }
    return map.toString();
  }
}

class DatabaseOpenHelper {
  final SembastDatabaseFactory factory;
  final String path;
  final DatabaseOpenOptions options;
  final lock = Lock();
  SembastDatabase database;

  DatabaseOpenHelper(this.factory, this.path, this.options);

  SembastDatabase newDatabase(String path) => factory.newDatabase(this);

  Future<Database> openDatabase() {
    return lock.synchronized(() async {
      if (this.database == null) {
        final database = newDatabase(path);
        // Affect before open to properly clean
        this.database = database;
      }
      await database.open(options);
      return this.database;
    });
  }

  Future lockedCloseDatabase() async {
    if (database != null) {
      factory.removeDatabaseOpenHelper(path);
      database = null;
    }
    return database;
  }

  @override
  String toString() => 'DatabaseOpenHelper($path, $options)';
}

abstract class SembastDatabaseFactory implements DatabaseFactory {
  /// The actual implementation
  SembastDatabase newDatabase(DatabaseOpenHelper openHelper);

  Future doDeleteDatabase(String path);

  void removeDatabaseOpenHelper(String path);
}

mixin DatabaseFactoryMixin implements SembastDatabaseFactory {
  // for single instances only
  Map<String, DatabaseOpenHelper> _databaseOpenHelpers =
      <String, DatabaseOpenHelper>{};

  Future<Database> openDatabaseWithOptions(
      String path, DatabaseOpenOptions options) {
    var helper = getDatabaseOpenHelper(path, options);
    return helper.openDatabase();
  }

  @override
  Future<Database> openDatabase(String path,
      {int version,
      OnVersionChangedFunction onVersionChanged,
      DatabaseMode mode,
      SembastCodec codec}) {
    return openDatabaseWithOptions(
        path,
        DatabaseOpenOptions(
            version: version,
            onVersionChanged: onVersionChanged,
            mode: mode,
            codec: codec));
  }

  DatabaseOpenHelper getDatabaseOpenHelper(
      String path, DatabaseOpenOptions options) {
    var helper = getExistingDatabaseOpenHelper(path);
    if (helper == null) {
      helper = DatabaseOpenHelper(this, path, options);
      setDatabaseOpenHelper(path, helper);
    }
    return helper;
  }

  DatabaseOpenHelper getExistingDatabaseOpenHelper(String path) {
    if (path != null) {
      return _databaseOpenHelpers[path];
    } else {
      return null;
    }
  }

  @override
  void removeDatabaseOpenHelper(String path) {
    if (path != null) {
      _databaseOpenHelpers.remove(path);
    }
  }

  void setDatabaseOpenHelper(String path, DatabaseOpenHelper helper) {
    if (path != null) {
      if (helper == null) {
        _databaseOpenHelpers.remove(path);
      } else {
        _databaseOpenHelpers[path] = helper;
      }
    }
  }

  @override
  Future deleteDatabase(String path) async {
    // Close existing open instance
    var helper = getExistingDatabaseOpenHelper(path);
    if (helper != null && helper.database != null) {
      // Wait any pending open/close action
      await helper.lock.synchronized(() {
        return helper.lockedCloseDatabase();
      });
    }
    return doDeleteDatabase(path);
  }

  // Flush all opened databases
  Future flush() async {
    var helpers = List<DatabaseOpenHelper>.from(_databaseOpenHelpers.values,
        growable: false);
    for (var helper in helpers) {
      await helper.database?.flush();
    }
  }
}
