@TestOn("vm")
library sembast.test_runner_io;

import 'io_test_common.dart';
import 'test_common.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/src/io/io_file_system.dart';
import 'test_runner_src_fs.dart' as test_runner_fs;

void main() {
  solo_test('fs', () {
    expect(ioDatabaseFactory.fs, ioFileSystem);
  });
  test_runner_fs.defineTests(ioFileSystem);
}
