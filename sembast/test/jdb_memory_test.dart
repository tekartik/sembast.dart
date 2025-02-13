import 'package:sembast/src/api/protected/database.dart';
import 'package:sembast/src/api/protected/jdb.dart';
import 'package:sembast/src/api/protected/type.dart';
import 'package:sembast/src/jdb/jdb_factory_memory.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/store_ref_impl.dart';

import 'jdb_test_common.dart';

JdbDatabaseMemory getJdbDatabase(Database database) =>
    ((database as SembastDatabase).storageJdb as SembastStorageJdb).jdbDatabase
        as JdbDatabaseMemory;

class JdbWriteEntryMock extends JdbRawWriteEntry {
  JdbWriteEntryMock({
    required int super.id,
    required Object key,
    dynamic super.value,
    bool? deleted,
  }) : super(
         deleted: deleted ?? false,
         record: SembastStoreRef<Key?, Value?>.main().record(key),
       );
}

void main() {
  var ctx = databaseTestContextJdbMemory;
  // var jdbFactory = ctx.jdbFactory as JdbFactoryMemory;
  group('jdb', () {
    test('open', () async {
      var db = await ctx.open('test');

      var jdb = getJdbDatabase(db);
      expect(jdb.toDebugMap(), {
        'entries': <Object>[],
        'infos': [
          {
            'id': 'meta',
            'value': {'version': 1, 'sembast': 1},
          },
        ],
      });
      var store = StoreRef<int, String>.main();
      var key = await store.add(db, 'test');
      expect(key, 1);
      expect(jdb.toDebugMap(), {
        'entries': [
          {
            'id': 1,
            'value': {'key': 1, 'value': 'test'},
          },
        ],
        'infos': [
          {'id': '_main_store_last_id', 'value': 1},
          {
            'id': 'meta',
            'value': {'version': 1, 'sembast': 1},
          },
          {'id': 'revision', 'value': 1},
        ],
      });
      key = await store.add(db, 'test');
      expect(key, 2);
      expect(jdb.toDebugMap(), {
        'entries': [
          {
            'id': 1,
            'value': {'key': 1, 'value': 'test'},
          },
          {
            'id': 2,
            'value': {'key': 2, 'value': 'test'},
          },
        ],
        'infos': [
          {'id': '_main_store_last_id', 'value': 2},
          {
            'id': 'meta',
            'value': {'version': 1, 'sembast': 1},
          },
          {'id': 'revision', 'value': 2},
        ],
      });

      await db.close();
    });

    test('importJournal', () async {
      var db = await ctx.open('test');
      var jdb = getJdbDatabase(db);
      expect(jdb.toDebugMap(), {
        'entries': <Object>[],
        'infos': [
          {
            'id': 'meta',
            'value': {'version': 1, 'sembast': 1},
          },
        ],
      });
      // Raw entry adding
      await jdb.addEntries([JdbWriteEntryMock(id: 1, key: 1, value: 'test')]);
      await jdb.setInfoEntry(
        JdbInfoEntry()
          ..id = '_main_store_last_id'
          ..value = 1,
      );
      await jdb.setInfoEntry(
        JdbInfoEntry()
          ..id = 'revision'
          ..value = 1,
      );
      expect(jdb.toDebugMap(), {
        'entries': [
          {
            'id': 1,
            'value': {'key': 1, 'value': 'test'},
          },
        ],
        'infos': [
          {'id': '_main_store_last_id', 'value': 1},
          {
            'id': 'meta',
            'value': {'version': 1, 'sembast': 1},
          },
          {'id': 'revision', 'value': 1},
        ],
      });
      var store = StoreRef<int, String>.main();
      var record1 = store.record(1);
      expect(await record1.get(db), isNull);

      // Add should trigger a reload
      // Its key will be +1 twice since a reload happens
      var key = await store.add(db, 'test');
      expect(jdb.toDebugMap(), {
        'entries': [
          {
            'id': 1,
            'value': {'key': 1, 'value': 'test'},
          },
          {
            'id': 2,
            'value': {'key': 3, 'value': 'test'},
          },
        ],
        'infos': [
          {'id': '_main_store_last_id', 'value': 3},
          {
            'id': 'meta',
            'value': {'version': 1, 'sembast': 1},
          },
          {'id': 'revision', 'value': 2},
        ],
      });
      expect(key, 3);
      expect(await record1.get(db), 'test');

      //TODO
      ////devPrint('2 ${await record1.onSnapshot(db).first}');
      await record1.onSnapshot(db).where((snapshot) => snapshot != null).first;
      expect(await store.record(1).get(db), isNotNull);

      await db.close();
    });

    test('jdbDatabase', () async {
      await ctx.jdbFactory.delete('test');
      var db =
          (await ctx.jdbFactory.open('test', DatabaseOpenOptions()))
              as JdbDatabaseMemory;
      expect(await db.getRevision(), 0);

      db.close();
    });
    test('JdbWriteEntry', () async {
      var txnRecord = TxnRecord(
        ImmutableSembastRecord.fromDatabaseRowMap({'key': 1, 'value': 1}),
      );
      var jdbWriteEntry = JdbWriteEntry(txnRecord: txnRecord);
      expect(jdbWriteEntry.valueOrNull, 1);
      expect(jdbWriteEntry.value, 1);
      jdbWriteEntry = JdbWriteEntry(txnRecord: txnRecord);
      // swap order
      expect(jdbWriteEntry.value, 1);
      expect(jdbWriteEntry.valueOrNull, 1);

      // deleted record
      jdbWriteEntry = JdbWriteEntry(
        txnRecord: TxnRecord(
          ImmutableSembastRecord.fromDatabaseRowMap({
            'key': 1,
            'deleted': true,
          }),
        ),
      );
      expect(jdbWriteEntry.valueOrNull, isNull);
    });
    test('JdbWriteEntryMock', () async {
      var jdbWriteEntry = JdbWriteEntryMock(id: 1, key: 2, value: 'test');
      expect(jdbWriteEntry.id, 1);
      expect(jdbWriteEntry.valueOrNull, 'test');

      expect(jdbWriteEntry.value, 'test');
      // swap order
      jdbWriteEntry = JdbWriteEntryMock(id: 1, key: 2, value: 'test');
      expect(jdbWriteEntry.value, 'test');
      expect(jdbWriteEntry.valueOrNull, 'test');
    });
    test('JdbRawWriteEntry', () async {
      var store = intMapStoreFactory.store();

      var jdbWriteEntry = JdbRawWriteEntry(
        deleted: false,
        value: 2,
        record: store.record(1),
      );
      expect(jdbWriteEntry.valueOrNull, 2);
      expect(jdbWriteEntry.value, 2);
      jdbWriteEntry = JdbRawWriteEntry(
        deleted: false,
        value: 2,
        record: store.record(1),
      );
      // swap order
      expect(jdbWriteEntry.value, 2);
      expect(jdbWriteEntry.valueOrNull, 2);
    });
  });
}
