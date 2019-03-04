import 'dart:async';

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
  Future<Database> openDatabaseWithOptions(
      String path, DatabaseOpenOptions options) {
    if (path != null) {
      path = fileSystemIo.absolute(path);
    }
    return super.openDatabaseWithOptions(path, options);
  }
}

/// The factory
// ignore: deprecated_member_use
final DatabaseFactoryIo databaseFactoryIo = DatabaseFactoryIo();

DatabaseFactory createDatabaseFactoryIo({String rootPath}) =>
    DatabaseFactoryIo(rootPath: rootPath);
