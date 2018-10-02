library sembast.test.io_test_common;

import 'package:path/path.dart';
import 'package:dev_test/test.dart';
import 'test_common.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/src/io/io_file_system.dart';

// For test in memory
IoDatabaseTestContext get ioDatabaseContext =>
    IoDatabaseTestContext()..factory = databaseFactoryIo;

class IoDatabaseTestContext extends FsDatabaseTestContext {
  String get dbPath => testOutPath + ".db";
}

IoFileSystemTestContext get ioFileSystemContext =>
    IoFileSystemTestContext()..fs = ioFileSystem;

class IoFileSystemTestContext extends FileSystemTestContext {
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
