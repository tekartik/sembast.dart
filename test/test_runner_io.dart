library sembast.test_runner_io;

import 'package:tekartik_test/test_config_io.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast.dart';
import 'test_runner.dart' as test_runner_test;

void main() {
  useVMConfiguration();
  defineTests(ioDatabaseFactory);
}
void defineTests(DatabaseFactory factory) {
  test_runner_test.defineTests(factory);
}
