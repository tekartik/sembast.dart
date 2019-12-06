@TestOn('vm')
@Timeout(Duration(seconds: 120))
library sembast.database_perf_test_slow;

// basically same as the io runner but with extra output
import 'package:test/test.dart';

import 'database_perf_test.dart' as database_perf_test;
import 'io_test_common.dart';

void main() {
  database_perf_test.defineTests(databaseContextIo, 1000,
      randomChoices: 20, randomCount: 10000);
}
