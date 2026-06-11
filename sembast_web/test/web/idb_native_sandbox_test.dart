@TestOn('browser')
library;

import 'package:sembast_web/sembast_web.dart';
import 'package:test/test.dart';

Future main() async {
  var factory = databaseFactoryWeb;

  group('idb_native_sandbox', () {
    test('open', () async {
      var sandboxed = factory.sandbox(path: 'sandbox');
      var store = StoreRef<String, String>.main();
      var record = store.record('key');
      await sandboxed.deleteDatabase('test');
      var db = await sandboxed.openDatabase('test');
      expect(await record.get(db), isNull);
      await record.put(db, 'value');
      expect(await record.get(db), 'value');

      expect(await sandboxed.databaseExists('test'), isTrue);
      expect(await factory.databaseExists('sandbox/test'), isTrue);

      var samedDb = await factory.openDatabase('sandbox/test');
      expect(samedDb, same(db));
      expect(await record.get(samedDb), 'value');
      await db.close();

      await sandboxed.deleteDatabase('test');
      expect(await factory.databaseExists('sandbox/test'), isFalse);
    });
  });
}
