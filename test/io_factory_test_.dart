@TestOn("vm")
library sembast.test.io_factory_test_;

import 'all_test.dart';
import 'io_test_common.dart';
import 'test_common.dart';

// default use memory
void main() {
  defineFileSystemTests(ioFileSystemContext);
  defineTests(ioDatabaseContext);
}
