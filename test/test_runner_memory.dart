library tekartik_iodb.test_runner_memory;

import 'package:tekartik_test/test_config_io.dart';
import 'package:sembast/database_memory.dart';
import 'package:sembast/database.dart';
import 'test_runner.dart' as test_runner_test;

void main() {
  useVMConfiguration();
  //debugQuickLogging(Level.FINEST);
  defineTests(memoryDatabaseFactory);
}
void defineTests(DatabaseFactory factory) {
  test_runner_test.defineTests(factory);
}

