library sembast.test.io_test_common;

import 'package:path/path.dart';
import 'package:dev_test/test.dart';
import 'test_common.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/src/io/file_system_io.dart';

// For test in memory
DatabaseTestContextIo get databaseContextIo =>
    DatabaseTestContextIo()..factory = databaseFactoryIo;

DatabaseTestContextIo createDatabaseContextIo({String rootPath}) =>
    DatabaseTestContextIo()
      ..factory = createDatabaseFactoryIo(rootPath: rootPath);

class DatabaseTestContextIo extends DatabaseTestContextFs {
  @override
  String get dbPath => testOutPath + ".db";
}

FileSystemTestContextIo get fileSystemContextIo =>
    FileSystemTestContextIo()..fs = FileSystemIo();

FileSystemTestContextIo createFileSystemContextIo({String rootPath}) =>
    FileSystemTestContextIo()..fs = FileSystemIo(rootPath: rootPath);

class FileSystemTestContextIo extends FileSystemTestContext {
  @override
  String get outPath => testOutPath;
}

String get testOutPath => getTestOutPath(testDescriptions);
String get testOutTopPath => join(".dart_tool", "sembast");

String getTestOutPath([List<String> parts]) {
  if (parts == null) {
    parts = testDescriptions;
  }
  return join(testOutTopPath, joinAll(parts));
}
/*

String clearTestOutPath([List<String> parts]) {
  String outPath = getTestOutPath(parts);
  try {
    new Directory(outPath).deleteSync(recursive: true);
  } catch (e) {}
  return outPath;
}
*/
