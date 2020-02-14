@TestOn('browser')
library sembast_test.test.web.idb_nativetest;

import 'package:idb_shim/idb_client_native.dart';
import 'package:sembast/src/sembast_jdb.dart';
import 'package:sembast_web/src/jdb_factory_idb.dart';
import 'package:sembast_test/all_test.dart';
import 'package:sembast_test/test_common.dart';
import 'package:test/test.dart';

Future main() async {
  var jdbFactory = JdbFactoryIdb(idbFactoryNative);
  var factory = DatabaseFactoryJdb(jdbFactory);

  var testContext = DatabaseTestContext()..factory = factory;

  group('idb_native', () {
    defineTests(testContext);
  });
}
