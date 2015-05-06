library sembast.test_runner_memory;

import 'package:sembast/src/memory/memory_file_system.dart';
import 'test_runner_src_fs.dart' as test_runner_fs_test;

void main() {
  defineTests();
}
void defineTests() {
  test_runner_fs_test.defineTests(memoryFileSystem);
}
