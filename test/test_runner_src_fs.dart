library sembast.test_runner_fs;

import 'package:sembast/src/sembast_fs.dart';
import 'package:sembast/src/file_system.dart';

import 'test_runner_all_test.dart' as test_runner_test;

void defineTests(FileSystem fs) {
  test_runner_test.defineTests(new FsDatabaseFactory(fs));
}
