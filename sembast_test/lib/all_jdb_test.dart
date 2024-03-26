import 'package:sembast_test/jdb_test_common.dart';

import 'database_codec_test.dart' as database_codec_test;
import 'jdb_concurrent_database_test.dart';
import 'jdb_database_format_test.dart' as jdb_database_format_test;
import 'jdb_database_test.dart' as jdb_database_test;

// default use memory
void main() {
  defineTests(databaseTestContextJdbMemory);
}

void defineTests(DatabaseTestContextJdb ctx) {
  jdb_database_format_test.defineTests(ctx);
  database_codec_test.defineTests(ctx);
  jdb_database_test.defineTests(ctx);
  defineJdbConcurrentDatabaseTests(ctx);
}
