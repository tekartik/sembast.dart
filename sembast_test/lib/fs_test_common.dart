import 'package:sembast/src/api/v2/sembast_memory.dart';
import 'package:sembast/src/file_system.dart';
import 'package:sembast/src/sembast_fs.dart';

import 'test_common.dart';

class DatabaseTestContextFs extends DatabaseTestContext {
  FileSystem get fs => (factory as DatabaseFactoryFs).fs;
}

DatabaseTestContextFs get memoryFsDatabaseContext =>
    DatabaseTestContextFs()..factory = databaseFactoryMemoryFs;
