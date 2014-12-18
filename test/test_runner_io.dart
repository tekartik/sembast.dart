library sembast.test_runner_io;

import 'package:tekartik_test/test_config_io.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/src/io/io_file_system.dart';
import 'test_runner_fs.dart' as test_runner_fs_test;

void main() {
  useVMConfiguration();
  defineTests();
}
void defineTests() {
  
  group('io', () {
    expect(ioDatabaseFactory.fs, ioFileSystem);
  });
  test_runner_fs_test.defineTests(ioFileSystem);
}
