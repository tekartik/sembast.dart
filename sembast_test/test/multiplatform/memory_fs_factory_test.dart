@TestOn('!wasm') // tmp
library;

import 'package:sembast_test/all_fs_test.dart' as all_fs_test;
import 'package:sembast_test/fs_test_common.dart';
import 'package:sembast_test/memory_fs_factory_test_.dart' as memory_fs;
import 'package:test/test.dart';

void main() {
  all_fs_test.defineTests(memoryFsDatabaseContext);
  memory_fs.main();
}
