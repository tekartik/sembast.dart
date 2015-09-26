@TestOn("vm")
@Timeout(const Duration(seconds: 120))
library sembast.database_perf_test_slow;

// basically same as the io runner but with extra output
import 'package:test/test.dart';
import 'package:sembast/sembast_io.dart';
import 'database_perf_test.dart' as database_perf_test;

void main() {
  database_perf_test.defineTests(ioDatabaseFactory, 1000,
      randomChoices: 20, randomCount: 10000);
}
