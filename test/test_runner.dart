library tekartik_iodb.test_runner;

import 'package:tekartik_test/test_config_io.dart';
import 'package:tekartik_iodb/database_memory.dart';
import 'package:tekartik_iodb/database_io.dart';
import 'database_perf_test.dart' as database_perf_test;
import 'database_test.dart' as database_test;
import 'crud_test.dart' as crud_test;
import 'record_test.dart' as record_test;
import 'find_test.dart' as find_test;
import 'store_test.dart' as store_test;
import 'transaction_test.dart' as transaction_test;
import 'package:tekartik_iodb/database.dart';

// default use memory
void main() {
  useVMConfiguration();
  group('memory', () {
    defineTests(memoryDatabaseFactory);
  });
  group('io', () {
    defineTests(ioDatabaseFactory);
  });

}
void defineTests(DatabaseFactory factory) {
  database_perf_test.defineTests(factory);
  database_test.defineTests(factory);
  crud_test.defineTests(factory);
  record_test.defineTests(factory);
  store_test.defineTests(factory);
  find_test.defineTests(factory);
  transaction_test.defineTests(factory);

}
