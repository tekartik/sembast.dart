library sembast.test_runner;

import 'package:sembast/src/memory/memory_file_system.dart';
import 'package:sembast/src/sembast_fs.dart';
import 'package:sembast/src/file_system.dart';
import 'database_perf_test.dart' as database_perf_test;
import 'database_test.dart' as database_test;
import 'crud_test.dart' as crud_test;
import 'record_test.dart' as record_test;
import 'key_test.dart' as key_test;
import 'find_test.dart' as find_test;
import 'store_test.dart' as store_test;
import 'transaction_test.dart' as transaction_test;
import 'package:sembast/sembast.dart';
import 'src_file_system_test.dart' as src_file_system_test;
import 'database_format_test.dart' as database_format_test;
import 'test_common.dart';

// default use memory
void main() {
  defineFileSystemTests(memoryFileSystem, null);
  defineTests(memoryFsDatabaseContext);
}

void defineFileSystemTests(FileSystem fs, String topPath) {
  src_file_system_test.defineTests(fs);
  database_format_test.defineTests(fs, topPath);
}

void defineTests(DatabaseTestContext ctx) {
  database_perf_test.defineTests(ctx, 10);
  database_test.defineTests(ctx);
  crud_test.defineTests(ctx);
  record_test.defineTests(ctx);
  key_test.defineTests(ctx);
  store_test.defineTests(ctx);
  find_test.defineTests(ctx);
  transaction_test.defineTests(ctx);
}
