library sembast.test_runner;

import 'package:tekartik_test/test_config_io.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/sembast_io.dart';
import 'package:idb_shim/idb_client.dart';
import 'idb_shim/idb_client_sembast.dart';
import 'database_perf_test.dart' as database_perf_test;
import 'database_test.dart' as database_test;
import 'idb_quick_standalone_test.dart' as idb_quick_standalone_test;
import 'crud_test.dart' as crud_test;
import 'record_test.dart' as record_test;
import 'find_test.dart' as find_test;
import 'store_test.dart' as store_test;
import 'transaction_test.dart' as transaction_test;
import 'package:sembast/sembast.dart';

// default use memory
void main() {
  useVMConfiguration();
  //debugQuickLogging(Level.FINEST);
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
  IdbFactory idbFactory = new IdbSembastFactory(factory, "tmp");
  idb_quick_standalone_test.defineTests(idbFactory);
}
