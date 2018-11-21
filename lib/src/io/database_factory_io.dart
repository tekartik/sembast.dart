import 'package:sembast/sembast.dart';
import 'package:sembast/src/database_factory_mixin.dart';
import 'package:sembast/src/io/file_system_io.dart';
import 'package:sembast/src/sembast_fs.dart';

/// Io file system implementation
class DatabaseFactoryIo extends DatabaseFactoryFs {
  FileSystemIo get fileSystemIo => fs as FileSystemIo;

  DatabaseFactoryIo({String rootPath})
      : super(FileSystemIo(rootPath: rootPath));

  @override
  Future<Database> openDatabase(String path,
      {int version,
      OnVersionChangedFunction onVersionChanged,
      DatabaseMode mode}) {
    // When using io make sure we never open twice the same file
    if (path != null) {
      path = fileSystemIo.absolute(path);
    }
    var helper = getDatabaseOpenHelper(
        path,
        DatabaseOpenOptions(
            version: version, onVersionChanged: onVersionChanged, mode: mode));
    return helper.openDatabase();
  }
}

/// The factory
// ignore: deprecated_member_use
final DatabaseFactoryIo databaseFactoryIo = DatabaseFactoryIo();

DatabaseFactory createDatabaseFactoryIo({String rootPath}) =>
    DatabaseFactoryIo(rootPath: rootPath);
