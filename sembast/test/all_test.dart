library sembast.test_runner;

import 'database_codec_test.dart' as database_codec_test;
import 'database_format_test.dart' as database_format_test;
import 'database_perf_test.dart' as database_perf_test;
import 'test_common.dart';
import 'transaction_impl_test.dart' as transaction_impl_test;

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
  database_perf_test.defineTests(ctx, 10);
  transaction_impl_test.defineTests(ctx);
}
