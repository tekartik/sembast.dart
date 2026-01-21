@TestOn('browser')
library;

import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/idb_jdb.dart';
import 'package:sembast_test/all_jdb_test.dart' as all_jdb_test;
import 'package:sembast_test/all_test.dart';
import 'package:sembast_test/jdb_test_common.dart';
import 'package:sembast_test/test_common.dart';
import 'package:test/test.dart';

Future main() async {
  var jdbFactory = JdbFactoryIdb(idbFactoryNative);
  var factory = DatabaseFactoryJdb(jdbFactory);

  var testContext = DatabaseTestContextJdb()..factory = factory;

  group('idb_native', () {
    defineTests(testContext);
    all_jdb_test.defineJdbTests(testContext);
  });
}
