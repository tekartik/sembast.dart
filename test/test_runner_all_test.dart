library sembast.test_runner;

import 'package:sembast/src/memory/memory_file_system.dart';
import 'package:sembast/src/sembast_fs.dart';
import 'package:sembast/src/file_system.dart';
import 'database_perf_test.dart' as database_perf_test;
import 'database_test.dart' as database_test;
import 'crud_test.dart' as crud_test;
import 'record_test.dart' as record_test;
import 'find_test.dart' as find_test;
import 'store_test.dart' as store_test;
import 'transaction_test.dart' as transaction_test;
import 'package:sembast/sembast.dart';
import 'test_runner_src_file_system.dart' as src_file_system_test;
import 'database_format_test.dart' as database_format_test;

// default use memory
void main() {
  defineFileSystemTests(memoryFileSystem);
  defineTests(new FsDatabaseFactory(memoryFileSystem));
}

void defineFileSystemTests(FileSystem fs) {
  src_file_system_test.defineTests(fs);
  database_format_test.defineTests(fs);
}

void defineTests(DatabaseFactory factory) {
  database_perf_test.defineTests(factory, 10);
  database_test.defineTests(factory);
  crud_test.defineTests(factory);
  record_test.defineTests(factory);
  store_test.defineTests(factory);
  find_test.defineTests(factory);
  transaction_test.defineTests(factory);
}
