@TestOn("vm")
library sembast.test.io_factory_test_;

import 'all_test.dart';
import 'io_test_common.dart';
import 'test_common.dart';

// already tested by all_factory_test
// helper for testing
void main() {
  defineFileSystemTests(fileSystemContextIo);
  defineTests(databaseContextIo);
}
