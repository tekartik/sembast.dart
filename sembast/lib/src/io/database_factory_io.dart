import 'dart:async';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/protected/database.dart';
import 'package:sembast/src/io/file_system_io.dart';
import 'package:sembast/src/sembast_fs.dart';

/// Io file system implementation
class DatabaseFactoryIo extends DatabaseFactoryFs {
  /// Io file system implementation
  DatabaseFactoryIo({String? rootPath})
    : super(FileSystemIo(rootPath: rootPath));

  /// The io file system.
  FileSystemIo get fileSystemIo => fs as FileSystemIo;

  @override
  Future<Database> openDatabaseWithOptions(
    String path,
    DatabaseOpenOptions options,
  ) {
    path = fileSystemIo.absolute(path);
    return super.openDatabaseWithOptions(path, options);
  }
}

/// The factory
// ignore: deprecated_member_use
final DatabaseFactoryIo databaseFactoryIo = DatabaseFactoryIo();

/// Create an IO factory with a root path.
DatabaseFactory createDatabaseFactoryIo({String? rootPath}) =>
    DatabaseFactoryIo(rootPath: rootPath);
