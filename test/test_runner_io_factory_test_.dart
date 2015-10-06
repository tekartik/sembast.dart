@TestOn("vm")
library sembast.test_runner.all_test;

import 'package:sembast/src/io/io_file_system.dart';
import 'test_runner_all_test.dart';
import 'package:sembast/sembast_io.dart';
import 'io_test_common.dart';
import 'test_common.dart';

// default use memory
void main() {
  group('io', () {
    defineFileSystemTests(ioFileSystem, testOutTopPath);
    defineTests(ioDatabaseContext);
  });
}
