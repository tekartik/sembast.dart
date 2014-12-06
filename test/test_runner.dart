library tekartik_iodb.test_runner;

import 'package:tekartik_test/test_config_io.dart';
import 'database_perf_test.dart' as database_perf_test;
import 'database_test.dart' as database_test;
import 'crud_test.dart' as crud_test;
import 'record_test.dart' as record_test;
import 'find_test.dart' as find_test;
import 'store_test.dart' as store_test;


void main() {
  useVMConfiguration();
  defineTests();
}
void defineTests() {
  database_perf_test.defineTests();
  database_test.defineTests();
  crud_test.defineTests();
  record_test.defineTests();
  store_test.defineTests();
  find_test.defineTests();

}
