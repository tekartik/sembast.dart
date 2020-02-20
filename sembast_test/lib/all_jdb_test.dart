import 'package:sembast_test/jdb_test_common.dart';

import 'jdb_database_format_test.dart' as jdb_database_format_test;

// default use memory
void main() {
  defineTests(databaseTestContextJdbMemory);
}

void defineTests(DatabaseTestContextJdb ctx) {
  jdb_database_format_test.defineTests(ctx);
}
