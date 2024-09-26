@Timeout(Duration(seconds: 120))
library;

// basically same as the io runner but with extra output
import 'database_perf_test.dart' as database_perf_test;
import 'test_common.dart';

void main() {
  // 1000 too high for dart2js => 500
  // 10000 too high for dart2js => 5000
  database_perf_test.defineTests(memoryDatabaseContext, 500,
      randomChoices: 15, randomCount: 5000);
}
