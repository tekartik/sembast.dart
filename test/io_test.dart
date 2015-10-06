@TestOn("vm")
library sembast.test.io_test;

import 'test_common.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/src/io/io_file_system.dart';

void main() {
  test('fs', () {
    expect(ioDatabaseFactory.fs, ioFileSystem);
  });
}
