library sembast.test_runner;

import 'crud_impl_test.dart' as crud_impl_test;
import 'crud_test.dart' as crud_test;
import 'database_codec_test.dart' as database_codec_test;
import 'database_format_test.dart' as database_format_test;
import 'database_test.dart' as database_test;
import 'doc_test.dart' as doc_test;
import 'exception_test.dart' as exception_test;
import 'exp_test.dart' as exp_test;
import 'find_test.dart' as find_test;
import 'key_test.dart' as key_test;
import 'open_test.dart' as open_test;
import 'store_api_test.dart' as store_api_test;
import 'store_test.dart' as store_test;
import 'test_common.dart';
import 'transaction_test.dart' as transaction_test;
import 'value_test.dart' as value_test;

// default use memory
void main() {
  defineFileSystemTests(memoryFileSystemContext);
  defineTests(memoryDatabaseContext);
}

void defineFileSystemTests(FileSystemTestContext ctx) {
  database_format_test.defineTests(ctx);
  database_codec_test.defineTests(ctx);
}

void defineTests(DatabaseTestContext ctx) {
  crud_test.defineTests(ctx);
  crud_impl_test.defineTests(ctx);
  database_test.defineTests(ctx);
  store_test.defineTests(ctx);
  find_test.defineTests(ctx);
  transaction_test.defineTests(ctx);
  key_test.defineTests(ctx);
  store_api_test.defineTests(ctx);
  doc_test.defineTests(ctx);
  open_test.defineTests(ctx);
  exception_test.defineTests(ctx);
  exp_test.defineTests(ctx);
  value_test.defineTests(ctx);
}
