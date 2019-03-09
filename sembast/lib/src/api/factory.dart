import 'package:sembast/src/api/database_mode.dart';
import 'package:sembast/src/api/sembast.dart';
import 'package:sembast/src/settings_impl.dart';

///
/// The database factory that allow opening database
///
abstract class DatabaseFactory {
  ///
  /// True if it has an associated storage (fs)
  ///
  bool get hasStorage;

  ///
  /// Open a new of existing database
  ///
  /// [path] is the location of the database
  /// [version] is the version expected, if not null and if the existing version is different, onVersionChanged is called.
  /// [mode] is [DatabaseMode.DEFAULT] by default
  ///
  /// A custom [code] can be used to load/save a record, allowing for user encryption
  /// When a database is created, its default version is 1
  ///
  Future<Database> openDatabase(String path,
      {int version,
      OnVersionChangedFunction onVersionChanged,
      DatabaseMode mode,
      SembastCodec codec,
      DatabaseSettings settings});

  ///
  /// Delete a database if existing
  ///
  Future deleteDatabase(String path);
}
