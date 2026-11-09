import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:sembast/src/api/v2/sembast.dart';

/// The database factory that allow opening database
///
/// The factory depends on the platform: `databaseFactoryIo`
/// (`package:sembast/sembast_io.dart`, Dart VM and Flutter mobile/desktop),
/// `databaseFactoryWeb` (`package:sembast_web`, web), `newDatabaseFactoryMemory()`
/// (`package:sembast/sembast_memory.dart`, tests) or
/// `getDatabaseFactorySqflite()` (`package:sembast_sqflite`). The returned
/// [Database] has the same API on every platform.
abstract class DatabaseFactory {
  /// True if it has an associated storage (fs, idb).
  ///
  /// false for memory
  bool get hasStorage;

  /// Open a new or existing database.
  ///
  /// [path] is the location of the database: a file path with
  /// `databaseFactoryIo` (use an absolute path in an app folder in Flutter), a
  /// database name on the web and in memory.
  ///
  /// Opening loads the whole database in memory. Open it once and keep the
  /// [Database] for the lifetime of the app. Opening a path already open
  /// returns the same instance (its [version] and [onVersionChanged] are then
  /// ignored).
  ///
  /// ```dart
  /// var db = await databaseFactoryIo.openDatabase(
  ///   path,
  ///   version: 1,
  ///   onVersionChanged: (db, oldVersion, newVersion) async {
  ///     if (oldVersion == 0) {
  ///       // Created: add initial data here.
  ///     }
  ///   },
  /// );
  /// ```
  ///
  /// [version] is the version expected, if not null and if the existing version
  /// is different, [onVersionChanged] is called.
  /// When a database is created, its default version is 1.
  ///
  /// [mode] is [DatabaseMode.defaultMode] by default.
  ///
  /// A custom [codec] can be used to load/save a record, allowing for user encryption.
  Future<Database> openDatabase(
    String path, {
    int? version,
    OnVersionChangedFunction? onVersionChanged,
    DatabaseMode? mode,
    SembastCodec? codec,
  });

  /// Delete a database if existing
  Future<void> deleteDatabase(String path);

  /// Check if a database exists
  Future<bool> databaseExists(String path);

  /// Path context
  p.Context get pathContext;
}

/// Callback interface called when the existing version differs from the
/// one expected.
///
/// Allow to perform migration or data change. Can return a future or not.
typedef OnVersionChangedFunction =
    FutureOr<dynamic> Function(Database db, int oldVersion, int newVersion);
