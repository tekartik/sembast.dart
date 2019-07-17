library sembast.test_runner;

import '../test_common.dart';
import 'crud_test.dart' as crud_test;
import 'database_codec_test.dart' as database_codec_test;
import 'database_format_test.dart' as database_format_test;
import 'database_impl_format_test.dart' as database_impl_format_test;
import 'database_import_export_test.dart' as database_import_export_test;
import 'database_perf_test.dart' as database_perf_test;
import 'database_test.dart' as database_test;
import 'database_utils_test.dart' as database_utils_test;
import 'doc_test.dart' as doc_test;
import 'exception_test.dart' as exception_test;
import 'exp_test.dart' as exp_test;
import 'find_test.dart' as find_test;
import 'key_test.dart' as key_test;
import 'record_test.dart' as record_test;
import 'src_file_system_test.dart' as src_file_system_test;
import 'store_test.dart' as store_test;
import 'transaction_test.dart' as transaction_test;
import 'value_test.dart' as value_test;

// default use memory
void main() {
  defineFileSystemTests(memoryFileSystemContext);
  defineTests(memoryDatabaseContext);
}

void defineFileSystemTests(FileSystemTestContext ctx) {
  src_file_system_test.defineTests(ctx);
  database_format_test.defineTests(ctx);
  database_codec_test.defineTests(ctx);
  database_impl_format_test.defineTests(ctx);
  doc_test.defineFileSystemTests(ctx);
}

void defineTests(DatabaseTestContext ctx) {
  database_perf_test.defineTests(ctx, 10);
  database_test.defineTests(ctx);
  crud_test.defineTests(ctx);
  record_test.defineTests(ctx);
  key_test.defineTests(ctx);
  value_test.defineTests(ctx);
  store_test.defineTests(ctx);
  find_test.defineTests(ctx);
  transaction_test.defineTests(ctx);
  exception_test.defineTests(ctx);
  database_import_export_test.defineTests(ctx);
  exp_test.defineTests(ctx);
  database_utils_test.defineTests(ctx);
  doc_test.defineTests(ctx);
}
