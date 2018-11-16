@TestOn("vm")
library sembast.test.io_factory_test_;

import 'package:path/path.dart';

import 'all_test.dart';
import 'io_test_common.dart';
import 'test_common.dart';

// already tested by all_factory_test
// helper for testing
void main() {
  var rootPath = join('.dart_tool', 'sembast', 'test', 'file_system_with_root');
  defineFileSystemTests(createFileSystemContextIo(rootPath: rootPath));
  defineTests(createDatabaseContextIo(rootPath: rootPath));
}
