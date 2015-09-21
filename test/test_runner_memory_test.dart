library sembast.test_runner_memory;

import 'package:sembast/sembast_memory.dart';
import 'package:sembast/sembast.dart';
import 'test_runner_all_test.dart' as test_runner_test;

void main() {
  defineTests(memoryDatabaseFactory);
}

void defineTests(DatabaseFactory factory) {
  test_runner_test.defineTests(factory);
}
