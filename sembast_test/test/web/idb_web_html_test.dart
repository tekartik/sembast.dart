@TestOn('browser')
library sembast_test.test.web.idb_nativetest;

import 'package:idb_shim/idb_client_native_html.dart';
import 'package:sembast_test/all_jdb_test.dart' as all_jdb_test;
import 'package:sembast_test/all_test.dart';
import 'package:sembast_test/jdb_test_common.dart';
import 'package:sembast_test/src/import_jdb.dart';
import 'package:sembast_test/test_common.dart';
import 'package:sembast_web/src/jdb_factory_idb.dart';
import 'package:test/test.dart';

Future main() async {
  var jdbFactory = JdbFactoryIdb(idbFactoryNative);
  var factory = DatabaseFactoryJdb(jdbFactory);

  var testContext = DatabaseTestContextJdb()..factory = factory;

  group('idb_native', () {
    defineTests(testContext);
    all_jdb_test.defineTests(testContext);
  });
}
