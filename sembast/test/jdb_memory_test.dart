import 'package:meta/meta.dart';
import 'package:sembast/src/api/protected/jdb.dart';
import 'package:sembast/src/api/v2/sembast.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/jdb/jdb_factory_memory.dart';
import 'package:test/test.dart';

import 'jdb_test_common.dart';

JdbDatabaseMemory getJdbDatabase(Database database) =>
    ((database as SembastDatabase).storageJdb as SembastStorageJdb).jdbDatabase
        as JdbDatabaseMemory;

class JdbWriteEntryMock extends JdbWriteEntry {
  @override
  RecordRef record;
  dynamic _value;
  bool _deleted;

  JdbWriteEntryMock(
      {int id,
      String store,
      @required dynamic key,
      dynamic value,
      bool deleted}) {
    record = (store == null ? StoreRef.main() : StoreRef(store)).record(key);
    _value = value;
    _deleted = deleted;
    this.id = id;
  }

  @override
  dynamic get value => _value;

  @override
  bool get deleted => _deleted;
}

void main() {
  var ctx = databaseTestContextJdbMemory;
  // var jdbFactory = ctx.jdbFactory as JdbFactoryMemory;
  group('jdb', () {
    test('open', () async {
      var db = await ctx.open('test');

      var jdb = getJdbDatabase(db);
      expect(jdb.toDebugMap(), {
        'entries': [],
        'infos': [
          {
            'id': '_meta',
            'value': {'version': 1, 'sembast': 1}
          }
        ]
      });
      var store = StoreRef<int, String>.main();
      var key = await store.add(db, 'test');
      expect(key, 1);
      expect(jdb.toDebugMap(), {
        'entries': [
          {'id': 1, 'store': '_main', 'key': 1, 'value': 'test'}
        ],
        'infos': [
          {
            'id': '_meta',
            'value': {'version': 1, 'sembast': 1}
          },
          {'id': '_main_store_last_id', 'value': 1}
        ]
      });
      key = await store.add(db, 'test');
      expect(key, 2);
      expect(jdb.toDebugMap(), {
        'entries': [
          {'id': 1, 'store': '_main', 'key': 1, 'value': 'test'},
          {'id': 2, 'store': '_main', 'key': 2, 'value': 'test'}
        ],
        'infos': [
          {
            'id': '_meta',
            'value': {'version': 1, 'sembast': 1}
          },
          {'id': '_main_store_last_id', 'value': 2}
        ]
      });

      await db.close();
    });

    test('importJournal', () async {
      var db = await ctx.open('test');
      var jdb = getJdbDatabase(db);
      expect(jdb.toDebugMap(), {
        'entries': [],
        'infos': [
          {
            'id': '_meta',
            'value': {'version': 1, 'sembast': 1}
          }
        ]
      });
      await jdb.addEntries([JdbWriteEntryMock(id: 1, key: 1, value: 'test')]);
      await jdb.setInfoEntry(JdbInfoEntry()
        ..id = '_main_store_last_id'
        ..value = 1);
      expect(jdb.toDebugMap(), {
        'entries': [
          {'id': 1, 'store': '_main', 'key': 1, 'value': 'test'}
        ],
        'infos': [
          {
            'id': '_meta',
            'value': {'version': 1, 'sembast': 1}
          },
          {'id': '_main_store_last_id', 'value': 1}
        ]
      });
      var store = StoreRef<int, String>.main();
      var record1 = store.record(1);
      expect(await record1.get(db), isNull);

      var key = await store.add(db, 'test');
      expect(key, 2);
      expect(await record1.get(db), isNull);

      await record1.onSnapshot(db).where((snapshot) => snapshot != null).first;

      expect(await store.record(1).get(db), isNotNull);

      await db.close();
    });
  });
}
