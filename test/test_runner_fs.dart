library sembast.test_runner_fs;

import 'package:sembast/src/sembast_fs.dart';
import 'package:sembast/src/file_system.dart';
import 'src_file_system_test.dart' as src_file_system_test;

import 'test_runner.dart' as test_runner_test;

void defineTests(FileSystem fs) {
  test_runner_test.defineTests(new FsDatabaseFactory(fs));
  src_file_system_test.defineTests(fs);
}
