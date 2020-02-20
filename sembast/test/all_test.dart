library sembast.test_runner;

import 'database_codec_test.dart' as database_codec_test;
import 'database_format_test.dart' as database_format_test;
import 'test_common.dart';

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
// store_api_test.defineTests(ctx);
}
