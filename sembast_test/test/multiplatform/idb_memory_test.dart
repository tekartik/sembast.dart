import 'package:sembast/src/sembast_jdb.dart';
import 'package:sembast_web/src/jdb_factory_idb.dart';
import 'package:sembast_test/all_test.dart';
import 'package:sembast_test/test_common.dart';
import 'package:test/test.dart';

Future main() async {
  var jdbFactory = jdbFactoryIdbMemory;
  var factory = DatabaseFactoryJdb(jdbFactory);
  var testContext = DatabaseTestContext()..factory = factory;

  group('idb_mem', () {
    defineTests(testContext);
  });
}
