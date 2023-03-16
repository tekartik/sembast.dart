@TestOn('vm')
library sembast_web.test.idb_io_simple_test;

import 'package:idb_shim/idb_io.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/protected/jdb.dart';
import 'package:sembast_web/src/jdb_factory_idb.dart';

import 'package:test/test.dart';
import 'multiplatform/idb_jdb_test.dart' as idb_jdb_test;

var testPath = '.dart_tool/sembast_web/databases';

Future main() async {
  var jdbFactory = JdbFactoryIdb(getIdbFactorySembastIo(testPath));
  var factory = DatabaseFactoryJdb(jdbFactory);

  group('idb_io', () {
    test('open', () async {
      var store = StoreRef<String, String>.main();
      var record = store.record('key');
      await factory.deleteDatabase('test');
      var db = await factory.openDatabase('test');
      expect(await record.get(db), isNull);
      await record.put(db, 'value');
      expect(await record.get(db), 'value');
      await db.close();

      db = await factory.openDatabase('test');
      await record.put(db, 'value');
      expect(await record.get(db), 'value');
      await db.close();
    });

    idb_jdb_test.defineTests(jdbFactory);
  });
}
