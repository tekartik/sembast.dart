@TestOn('!wasm')
library;

import 'package:sembast/sembast.dart';
import 'package:sembast_web/src/jdb_factory_idb.dart';
import 'package:sembast_web/src/jdb_import.dart';
import 'package:test/test.dart';

Future main() async {
  var jdbFactory = jdbFactoryIdbMemory;
  var factory = DatabaseFactoryJdb(jdbFactory);

  group('idb_mem', () {
    test('open', () async {
      var store = StoreRef<String, String>.main();
      var record = store.record('key');
      await factory.deleteDatabase('test');
      var db = await factory.openDatabase('test');
      await record.put(db, 'value');
      expect(await record.get(db), 'value');
      await db.close();

      db = await factory.openDatabase('test');
      await record.put(db, 'value');
      expect(await record.get(db), 'value');
      await db.close();
    });
  });
}
