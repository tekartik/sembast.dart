// @deprecated
library sembast.test.dev_test_common;

import 'package:path/path.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/src/file_system.dart';
import 'package:sembast/src/sembast_fs.dart';

import 'src/test_defs_dev.dart';
import 'test_common.dart';
import 'test_common.dart' as common;

export 'src/test_defs_dev.dart';
export 'test_common.dart' hide setupForTest;

// For test in memory
DevDatabaseTestContext get devMemoryDatabaseContext =>
    DevDatabaseTestContext()..factory = databaseFactoryMemory;

DevDatabaseTestContextFs get devMemoryFsDatabaseContext =>
    DevDatabaseTestContextFs()..factory = databaseFactoryMemoryFs;

class DevDatabaseTestContextFs extends DevDatabaseTestContext {
  FileSystem get fs => (factory as DatabaseFactoryFs).fs;

  @override
  String get dbPath => join(fs.currentDirectory.path, super.dbPath);
}

Future<Database> setupForTest(DatabaseTestContext ctx) {
  return common.setupForTest(ctx, null);
}
