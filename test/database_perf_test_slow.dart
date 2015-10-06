@Timeout(const Duration(seconds: 120))
library sembast.database_perf_test_slow;

// basically same as the io runner but with extra output
import 'test_common.dart';
import 'database_perf_test.dart' as database_perf_test;

void main() {
  // 1000 too high for dart2js => 500
  // 10000 too high for dart2js => 5000
  database_perf_test.defineTests(memoryDatabaseContext, 500,
      randomChoices: 15, randomCount: 5000);
}
