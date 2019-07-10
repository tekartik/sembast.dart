import 'package:path/path.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/src/file_system.dart';
import 'package:sembast/src/sembast_fs.dart';

import 'src/test_defs_dev.dart';

export 'src/test_defs_dev.dart';
export 'test_common.dart';

// For test in memory
DevDatabaseTestContext get devMemoryDatabaseContext =>
    DevDatabaseTestContext()..factory = databaseFactoryMemory;

DatabaseTestContextFs get memoryFsDatabaseContext =>
    DatabaseTestContextFs()..factory = databaseFactoryMemoryFs;

class DatabaseTestContextFs extends DevDatabaseTestContext {
  FileSystem get fs => (factory as DatabaseFactoryFs).fs;

  @override
  String get dbPath => join(fs.currentDirectory.path, super.dbPath);
}
