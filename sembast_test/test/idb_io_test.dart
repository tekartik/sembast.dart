import 'package:idb_shim/idb_io.dart';
import 'package:sembast/src/sembast_jdb.dart';
import 'package:sembast_web/src/jdb_factory_idb.dart';
import 'package:sembast_test/all_test.dart';
import 'package:sembast_test/test_common.dart';
import 'package:test/test.dart';

var testPath = '.dart_tool/sembast_test/idb/databases';

Future main() async {
  var jdbFactory = JdbFactoryIdb(getIdbFactorySembastIo(testPath));
  var factory = DatabaseFactoryJdb(jdbFactory);

  var testContext = DatabaseTestContext()..factory = factory;

  group('idb_io', () {
    defineTests(testContext);
  });
}
