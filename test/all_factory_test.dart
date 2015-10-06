@TestOn("vm")
library sembast.test_runner.all_test;

import 'all_test.dart';
import 'io_test_common.dart';
import 'test_common.dart';

// default use memory
void main() {
  //debugQuickLogging(Level.FINEST);
  group('memory', () {
    defineTests(memoryDatabaseContext);
  });
  group('io', () {
    defineFileSystemTests(ioFileSystemContext);
    defineTests(ioDatabaseContext);
  });
  group('memory_fs', () {
    defineFileSystemTests(memoryFileSystemContext);
    defineTests(memoryFsDatabaseContext);
  });
}
