import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/protected/database.dart';
import 'package:sembast/src/api/protected/jdb.dart';

/// Jdb implementation
class DatabaseFactoryJdb extends SembastDatabaseFactory
    with SembastDatabaseFactoryMixin
    implements DatabaseFactory {
  /// File system used.
  final JdbFactory jdbFactory;

  /// Constructor.
  DatabaseFactoryJdb(this.jdbFactory);

  @override
  SembastDatabase newDatabase(DatabaseOpenHelper openHelper) => SembastDatabase(
      openHelper,
      SembastStorageJdb(jdbFactory, openHelper.path,
          options: openHelper.options));

  @override
  Future doDeleteDatabase(String path) async {
    return SembastStorageJdb(jdbFactory, path).delete();
  }

  @override
  bool get hasStorage => true;

  @override
  Future<bool> databaseExists(String path) => jdbFactory.exists(path);
}
