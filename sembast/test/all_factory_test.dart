@TestOn("vm")
library sembast.test_runner.all_test;

import 'package:path/path.dart';

import 'all_test.dart';
import 'fs_test_common.dart';
import 'io_test_common.dart';
import 'memory_factory_test_.dart';
import 'test_common.dart';

// default use memory
void main() {
  //debugQuickLogging(Level.FINEST);
  group('memory', () {
    defineMemoryDatabaseTests(memoryDatabaseContext);
    defineTests(memoryDatabaseContext);
  });
  group('io', () {
    defineFileSystemTests(fileSystemContextIo);
    defineTests(databaseContextIo);
  });
  group('io_with_root', () {
    var rootPath = join('.dart_tool', 'sembast', 'test_io_with_root');
    defineFileSystemTests(createFileSystemContextIo(rootPath: rootPath));
    defineTests(createDatabaseContextIo(rootPath: rootPath));
  });
  group('memory_fs', () {
    defineFileSystemTests(memoryFileSystemContext);
    defineTests(memoryFsDatabaseContext);
  });
}
