import 'package:sembast_test/fs_test_common.dart';

import 'database_codec_test.dart' as database_codec_test;
import 'fs_database_format_test.dart' as fs_database_format_test;

// default use memory
void main() {
  defineTests(memoryFsDatabaseContext);
}

void defineTests(DatabaseTestContextFs ctx) {
  fs_database_format_test.defineTests(ctx);
  database_codec_test.defineTests(ctx);
}
