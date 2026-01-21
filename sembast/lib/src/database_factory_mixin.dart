import 'dart:async';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/database_impl.dart';

import 'database_open_helper.dart';
import 'database_open_options.dart';

/// Debug print the absolute path of the opened database.
var debugPrintAbsoluteOpenedDatabasePath = false;

/// Compat.
typedef SembastDatabaseFactory = DatabaseFactorySembast;

/// The factory implementation.
abstract class DatabaseFactorySembast implements DatabaseFactory {
  /// The actual implementation
  SembastDatabase newDatabase(DatabaseOpenHelper openHelper);

  /// Delete a database.
  Future doDeleteDatabase(String path);

  /// Set the helper for a given path.
  void setDatabaseOpenHelper(String path, DatabaseOpenHelper helper);

  /// Remove the helper for a given path.
  void removeDatabaseOpenHelper(String path);
}

/// Database factory mixin. to deprecate.
/// @Deprecated('use SembastDatabaseFactoryMixin')
typedef DatabaseFactoryMixin = SembastDatabaseFactoryMixin;

/// Database factory mixin.
mixin SembastDatabaseFactoryMixin implements SembastDatabaseFactory {
  // for single instances only
  final _databaseOpenHelpers = <String, DatabaseOpenHelper>{};

  /// Open a database with a given set of options.
  Future<Database> openDatabaseWithOptions(
    String path,
    DatabaseOpenOptions options,
  ) async {
    if (options.mode == DatabaseMode.readOnly) {
      if (options.version != null) {
        throw ArgumentError('readOnly mode does not support version');
      }
    }
    // Always specify the default codec
    var helper = await getDatabaseOpenHelper(path, options);
    return await helper.openDatabase();
  }

  @override
  Future<Database> openDatabase(
    String path, {
    int? version,
    OnVersionChangedFunction? onVersionChanged,
    DatabaseMode? mode,
    SembastCodec? codec,
  }) {
    return openDatabaseWithOptions(
      path,
      DatabaseOpenOptions(
        version: version,
        onVersionChanged: onVersionChanged,
        mode: mode,
        codec: codec,
      ),
    );
  }

  /// Get or create the open helper for a given path.
  Future<DatabaseOpenHelper> getDatabaseOpenHelper(
    String path,
    DatabaseOpenOptions options,
  ) async {
    DatabaseOpenHelper newHelper() {
      var helper = DatabaseOpenHelper(this, path, options);
      setDatabaseOpenHelper(path, helper);
      return helper;
    }

    var helper = getExistingDatabaseOpenHelper(path);
    if (helper == null) {
      return newHelper();
    } else {
      /// Wait if closing and create a new one
      if (helper.closing) {
        await helper.closeCompleted;
        return newHelper();
      }
      return helper;
    }
  }

  /// Get existing open helper for a given path.
  DatabaseOpenHelper? getExistingDatabaseOpenHelper(String path) {
    return _databaseOpenHelpers[path];
  }

  @override
  void removeDatabaseOpenHelper(String path) {
    _databaseOpenHelpers.remove(path);
  }

  @override
  void setDatabaseOpenHelper(String path, DatabaseOpenHelper? helper) {
    _databaseOpenHelpers.remove(path);
    _databaseOpenHelpers[path] = helper!;
  }

  @override
  Future deleteDatabase(String path) async {
    // Close existing open instance
    var helper = getExistingDatabaseOpenHelper(path);
    var helperDatabase = helper?.database;
    if (helperDatabase != null) {
      await helperDatabase.close();
    }
    return doDeleteDatabase(path);
  }

  /// Flush all opened databases
  Future flush() async {
    var helpers = List<DatabaseOpenHelper>.from(
      _databaseOpenHelpers.values,
      growable: false,
    );
    for (var helper in helpers) {
      await helper.database?.flush();
    }
  }

  @override
  Future<bool> databaseExists(String path) async =>
      throw UnimplementedError('databaseExists');
}
