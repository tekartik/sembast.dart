import 'dart:async';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/factory.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:synchronized/synchronized.dart';

/// Open options.
class DatabaseOpenOptions {
  /// version.
  final int version;

  /// open callback.
  final OnVersionChangedFunction onVersionChanged;

  /// open mode.
  final DatabaseMode mode;

  /// codec.
  final SembastCodec codec;

  /// Open options.
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

/// Open helper.
class DatabaseOpenHelper {
  /// The factory.
  final SembastDatabaseFactory factory;

  /// The path.
  final String path;

  /// The open options.
  final DatabaseOpenOptions options;

  /// The locker.
  final lock = Lock();

  /// The database.
  SembastDatabase database;

  /// Open helper.
  DatabaseOpenHelper(this.factory, this.path, this.options);

  /// Create a new database object.
  SembastDatabase newDatabase(String path) => factory.newDatabase(this);

  /// Open the database.
  Future<Database> openDatabase() {
    return lock.synchronized(() async {
      if (this.database == null) {
        final database = newDatabase(path);
        // Affect before open to properly clean
        this.database = database;
      }
      // Force helper again in case it was removed by lockedClose
      database.openHelper = this;

      await database.open(options);

      // Force helper again in case it was removed by lockedClose
      factory.setDatabaseOpenHelper(path, this);
      return this.database;
    });
  }

  /// Closed the database.
  Future lockedCloseDatabase() async {
    if (database != null) {
      factory.removeDatabaseOpenHelper(path);
      // database = null;
    }
    return database;
  }

  @override
  String toString() => 'DatabaseOpenHelper($path, $options)';
}

/// The factory implementation.
abstract class SembastDatabaseFactory implements DatabaseFactory {
  /// The actual implementation
  SembastDatabase newDatabase(DatabaseOpenHelper openHelper);

  /// Delete a database.
  Future doDeleteDatabase(String path);

  /// Set the helper for a given path.
  void setDatabaseOpenHelper(String path, DatabaseOpenHelper helper);

  /// Remove the helper for a given path.
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

  @override
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
