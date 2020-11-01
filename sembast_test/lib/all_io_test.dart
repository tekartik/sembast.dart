@TestOn('vm')
import 'package:sembast_test/src/test/test.dart';

import 'database_import_export_io_test.dart';
import 'io_test_common.dart';

// default use memory
void main() {
  allIoGroup(createDatabaseContextIo());
}

void allIoGroup(DatabaseTestContextIo ctx) {
  databaseImportExportIoGroup(ctx);
}
