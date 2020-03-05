library sembast.compat.test_runner;


import 'database_import_export_test.dart' as database_import_export_test;
import 'src_file_system_test.dart' as src_file_system_test;
import 'test_common.dart';

// default use memory
void main() {
  defineFileSystemTests(memoryFileSystemContext);
  defineTests(memoryDatabaseContext);
}

void defineFileSystemTests(FileSystemTestContext ctx) {
  src_file_system_test.defineTests(ctx);
}

void defineTests(DatabaseTestContext ctx) {
  database_import_export_test.defineTests(ctx);
}
