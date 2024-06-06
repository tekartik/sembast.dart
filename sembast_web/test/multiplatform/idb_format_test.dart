library;

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:idb_shim/utils/idb_utils.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast_web/src/jdb_factory_idb.dart' show JdbFactoryIdb;
import 'package:sembast_web/src/jdb_import.dart';
import 'package:test/test.dart';

Future main() async {
  var jdbFactoryIdb = JdbFactoryIdb(idbFactoryMemoryFs);
  defineTests(jdbFactoryIdb);
}

void defineTests(JdbFactoryIdb jdbFactoryIdb) {
  var factory = DatabaseFactoryJdb(jdbFactoryIdb);
  var idbFactory = jdbFactoryIdb.idbFactory;
  group('idb_format', () {
    test('format 1 record', () async {
      var store = StoreRef<String, String>.main();
      var record = store.record('key');
      await factory.deleteDatabase('test');
      var db = await factory.openDatabase('test');
      await record.put(db, 'value');
      expect(await record.get(db), 'value');
      await db.close();

      var idb = await idbFactory.open('test');
      expect(
          List<String>.from(idb.objectStoreNames)..sort(), ['entry', 'info']);
      var txn = idb.transaction(['entry', 'info'], idbModeReadOnly);
      var infos = await cursorToList(
          txn.objectStore('info').openCursor(autoAdvance: true));
      var entries = await cursorToList(
          txn.objectStore('entry').openCursor(autoAdvance: true));
      expect(infos.map((e) => [e.primaryKey, e.value]), [
        [
          'meta',
          {'version': 1, 'sembast': 1}
        ],
        ['revision', 1]
      ]);
      expect(entries.map((e) => [e.primaryKey, e.value]), [
        [
          1,
          {'store': '_main', 'key': 'key', 'value': 'value'}
        ]
      ]);
      await txn.completed;
      idb.close();
    });
  });
}
