import 'package:sembast/src/api/v2/sembast.dart';

///
/// The database factory that allow opening database
///
abstract class DatabaseFactory {
  /// True if it has an associated storage (fs, idb).
  ///
  /// false for memory
  bool get hasStorage;

  ///
  /// Open a new or existing database.
  ///
  /// [path] is the location of the database.
  ///
  /// [version] is the version expected, if not null and if the existing version is different, onVersionChanged is called.
  /// When a database is created, its default version is 1.
  ///
  /// [mode] is [DatabaseMode.defaultMode] by default.
  ///
  /// A custom [codec] can be used to load/save a record, allowing for user encryption.
  ///
  /// Custom [settings] can be specified.
  Future<Database> openDatabase(String path,
      {int version,
      OnVersionChangedFunction onVersionChanged,
      DatabaseMode mode,
      SembastCodec codec});

  ///
  /// Delete a database if existing
  ///
  Future deleteDatabase(String path);
}
