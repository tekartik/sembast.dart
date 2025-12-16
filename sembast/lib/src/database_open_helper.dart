import 'package:path/path.dart';
import 'package:sembast/sembast.dart';
import 'package:synchronized/synchronized.dart';

import 'api/protected/database.dart';
import 'common_import.dart';
import 'database_factory_mixin.dart';

/// Open helper. not public.
class DatabaseOpenHelper {
  /// The factory.
  final SembastDatabaseFactory factory;

  /// The path.
  final String path;

  /// The open mode that change overtime (empty to defaults)
  DatabaseMode? openMode;

  /// The open options.
  final DatabaseOpenOptions options;

  /// The locker.
  final lock = Lock();

  var _closing = false;

  /// True if closing
  bool get closing => _closing;

  /// The database.
  SembastDatabase? database;

  /// Open helper.
  DatabaseOpenHelper(this.factory, this.path, this.options) {
    /// Always set an open mode
    openMode ??= options.mode ?? DatabaseMode.defaultMode;
  }

  final _closeCompleter = Completer<void>();

  /// Set when the database is closed to handle race re-open cases
  Future<void> get closeCompleted => _closeCompleter.future;

  /// Create a new database object.
  SembastDatabase newDatabase(String path) => factory.newDatabase(this);

  /// Open the database.
  Future<Database> openDatabase() {
    return lock.synchronized(() async {
      if (database == null) {
        final database = newDatabase(path);
        // Affect before open to properly clean
        this.database = database;
      }
      // Force helper again in case it was removed by lockedClose
      database!.openHelper = this;

      if (debugPrintAbsoluteOpenedDatabasePath) {
        // ignore: avoid_print
        print('Opening ${normalize(absolute(path))}');
      }
      await database!.open(options);

      // Force helper again in case it was removed by lockedClose
      factory.setDatabaseOpenHelper(path, this);
      return database!;
    });
  }

  /// Mark the database as closing.
  /// others should wait for close to complete.
  void markClosing() {
    _closing = true;
  }

  /// Closed the database.
  Future lockedCloseDatabase() async {
    assert(_closing);
    if (database != null) {
      /// Last step remove helper to allow re-open
      factory.removeDatabaseOpenHelper(path);
      if (!_closeCompleter.isCompleted) {
        _closeCompleter.complete();
      }
    }
    return database;
  }

  @override
  String toString() => 'DatabaseOpenHelper($path, $options)';
}
