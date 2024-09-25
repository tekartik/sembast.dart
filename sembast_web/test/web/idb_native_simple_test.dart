// ignore_for_file: avoid_print

@TestOn('browser')
library sembast_web.test.web.idb_native_simple_test;

import 'package:sembast_web/sembast_web.dart';
import 'package:test/test.dart';
import 'package:web/web.dart';

import '../multiplatform/idb_jdb_test.dart' as idb_jdb_test;
import '../multiplatform/idb_jdb_test.dart';

var testPath = '.dart_tool/sembast_web/databases';

Future main() async {
  var factory = databaseFactoryWeb;

  group('idb_native', () {
    test('doc', () async {
      // Declare our store (records are mapd, ids are ints)
      var store = intMapStoreFactory.store();
      var factory = databaseFactoryWeb;
      await factory.deleteDatabase('test');

      // Open the database
      var db = await factory.openDatabase('test');

      // Add a new record
      var key =
          await store.add(db, <String, Object?>{'name': 'Table', 'price': 15});

      // Read the record
      var value = await store.record(key).get(db);

      // Print the value
      print(value);

      // Close the database
      await db.close();
    });

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

    test('storage_notification', () async {
      var store = StoreRef<String, String>.main();
      await factory.deleteDatabase('test');
      var db = await factory.openDatabase('test');
      expect(window.localStorage['sembast_web/revision:test'], isNull);
      var record = store.record('my_key');
      await record.put(db, 'my_value');
      expect(window.localStorage['sembast_web/revision:test'], '1');
      await db.close();
      expect(window.localStorage['sembast_web/revision:test'], '1');
      // Make sure the storage gets clears on deletion
      await factory.deleteDatabase('test');
      expect(window.localStorage['sembast_web/revision:test'], isNull);
    });

    idb_jdb_test.defineTests(
        asJdbJactoryIdb(asDatabaseFactoryIdb(databaseFactoryWeb).jdbFactory));
  });
}
