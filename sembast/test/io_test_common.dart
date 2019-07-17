library sembast.test.io_test_common;

import 'package:sembast/src/api/v2/sembast_io.dart';
import 'package:sembast/src/io/file_system_io.dart';

import 'fs_test_common.dart';
import 'test_common.dart';

// For test in memory
DatabaseTestContextIo get databaseContextIo =>
    DatabaseTestContextIo()..factory = databaseFactoryIo;

DatabaseTestContextIo createDatabaseContextIo({String rootPath}) =>
    DatabaseTestContextIo()
      ..factory = createDatabaseFactoryIo(rootPath: rootPath);

class DatabaseTestContextIo extends DatabaseTestContextFs {}

FileSystemTestContextIo get fileSystemContextIo =>
    FileSystemTestContextIo()..fs = FileSystemIo();

FileSystemTestContextIo createFileSystemContextIo({String rootPath}) =>
    FileSystemTestContextIo()..fs = FileSystemIo(rootPath: rootPath);

class FileSystemTestContextIo extends FileSystemTestContext {}
