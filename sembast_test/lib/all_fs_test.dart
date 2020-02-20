import 'package:sembast_test/fs_test_common.dart';

import 'fs_database_format_test.dart' as fs_database_format_test;

// default use memory
void main() {
  defineTests(memoryFsDatabaseContext);
}

void defineTests(DatabaseTestContextFs ctx) {
  fs_database_format_test.defineTests(ctx);
}
