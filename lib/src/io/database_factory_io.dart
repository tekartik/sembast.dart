import 'package:sembast/sembast.dart';
import 'package:sembast/src/io/file_system_io.dart';
import 'package:sembast/src/sembast_fs.dart';

/// Io file system implementation
class DatabaseFactoryIo extends DatabaseFactoryFs {
  DatabaseFactoryIo({String rootPath})
      : super(FileSystemIo(rootPath: rootPath));
}

/// The factory
// ignore: deprecated_member_use
final DatabaseFactoryIo databaseFactoryIo = DatabaseFactoryIo();

DatabaseFactory createDatabaseFactoryIo({String rootPath}) =>
    DatabaseFactoryIo(rootPath: rootPath);
