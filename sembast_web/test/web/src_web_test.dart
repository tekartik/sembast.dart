@TestOn('browser')
library sembast_web.test.web.src_web_test;

import 'package:sembast/sembast.dart';
import 'package:sembast_web/src/browser.dart';
import 'package:test/test.dart';

var testPath = '.dart_tool/sembast_web/databases';

Future main() async {
  var factory = databaseFactoryWeb;

  group('web', () {
    test('notification', () async {
      var revisionFuture = storageRevisionStream.first;
      var store = StoreRef<String, String>.main();
      var record = store.record('key');
      await factory.deleteDatabase('test');
      var db = await factory.openDatabase('test');
      expect(await record.get(db), isNull);
      await record.put(db, 'value');
      expect(await record.get(db), 'value');

      try {
        var storageRevision =
            await revisionFuture.timeout(const Duration(seconds: 10));
        expect(storageRevision.name, 'test');
        expect(storageRevision.revision, greaterThanOrEqualTo(1));
      } catch (e) {
        print(e);
      }
      await db.close();
    });
  });
}
