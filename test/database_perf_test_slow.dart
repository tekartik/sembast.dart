@Timeout(const Duration(seconds: 120))

library sembast.database_perf_test_slow;

// basically same as the io runner but with extra output
import 'package:test/test.dart';
import 'package:sembast/sembast_memory.dart';
import 'database_perf_test.dart' as database_perf_test;

void main() {
  database_perf_test.defineTests(memoryDatabaseFactory, 1000);
}
