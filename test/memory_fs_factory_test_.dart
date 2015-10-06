@TestOn("vm")
library sembast.test.memory_fs_factory_test_;

import 'all_test.dart';
import 'test_common.dart';

// default use memory
void main() {
  defineFileSystemTests(memoryFileSystemContext);
  defineTests(memoryFsDatabaseContext);
}
