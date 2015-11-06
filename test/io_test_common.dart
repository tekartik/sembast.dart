library sembast.test.io_test_common;

import 'dart:mirrors';
import 'package:path/path.dart';
import 'package:dev_test/test.dart';
import 'test_common.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/src/io/io_file_system.dart';

// For test in memory
IoDatabaseTestContext get ioDatabaseContext =>
    new IoDatabaseTestContext()..factory = ioDatabaseFactory;

class IoDatabaseTestContext extends FsDatabaseTestContext {
  String get dbPath => testOutPath + ".db";
}

IoFileSystemTestContext get ioFileSystemContext =>
    new IoFileSystemTestContext()..fs = ioFileSystem;

class IoFileSystemTestContext extends FileSystemTestContext {
  String get outPath => testOutPath;
}

class _TestUtils {
  static final String scriptPath =
      (reflectClass(_TestUtils).owner as LibraryMirror).uri.toFilePath();
}

String get testScriptPath => _TestUtils.scriptPath;
String get testOutPath => getTestOutPath(testDescriptions);
String get testOutTopPath => join(dirname(testScriptPath), "test_out");

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
