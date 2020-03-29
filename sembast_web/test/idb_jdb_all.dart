import 'package:idb_shim/idb_client_memory.dart';
import 'package:idb_shim/utils/idb_import_export.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast_web/src/jdb_factory_idb.dart'
    show JdbFactoryIdb, JdbDatabaseIdb;
import 'package:sembast_web/src/jdb_import.dart';
import 'package:test/test.dart';

DatabaseFactoryJdb asDatabaseFactoryIdb(DatabaseFactory databaseFactory) =>
    databaseFactory as DatabaseFactoryJdb;

JdbFactoryIdb asJdbJactoryIdb(JdbFactory factory) => factory as JdbFactoryIdb;

SembastDatabase asSembastDatabase(Database db) => db as SembastDatabase;

SembastStorageJdb asSembastStorateJdb(StorageJdb storageJdb) =>
    storageJdb as SembastStorageJdb;

JdbDatabaseIdb asJsbDatabaseIdb(JdbDatabase database) =>
    database as JdbDatabaseIdb;

JdbDatabaseIdb dbAsJsbDatabaseIdb(Database db) => asJsbDatabaseIdb(
    asSembastStorateJdb(asSembastDatabase(db).storageJdb).jdbDatabase);

Future main() async {
  var jdbFactoryIdb = JdbFactoryIdb(idbFactoryMemoryFs);
  defineTests(jdbFactoryIdb);
}

void defineTests(JdbFactoryIdb jdbFactoryIdb) {
  var factory = DatabaseFactoryJdb(jdbFactoryIdb);
  group('jdb_idb', () {
    group('simple_export', () {
      var export = {
        'sembast_export': 1,
        'version': 1,
        'stores': [
          {
            'name': '_main',
            'keys': ['store_entry', 'store_info', 'stores', 'version'],
            'values': [
              {
                'name': 'entry',
                'autoIncrement': true,
                'indecies': [
                  {
                    'name': 'record',
                    'keyPath': ['store', 'key']
                  },
                  {'name': 'deleted', 'keyPath': 'deleted', 'multiEntry': true}
                ]
              },
              {'name': 'info'},
              ['info', 'entry'],
              2
            ]
          },
          {
            'name': 'info',
            'keys': ['meta', 'revision'],
            'values': [
              {'version': 1, 'sembast': 1},
              1
            ]
          },
          {
            'name': 'entry',
            'keys': [1],
            'values': [
              {'store': '_main', 'key': 'key', 'value': 'value'}
            ]
          }
        ]
      };

      test('export', () async {
        var store = StoreRef<String, String>.main();
        var record = store.record('key');
        await factory.deleteDatabase('test');
        var db = await factory.openDatabase('test');
        expect(await record.get(db), isNull);
        await record.put(db, 'value');
        expect(await record.get(db), 'value');
        expect(await dbAsJsbDatabaseIdb(db).sdbExportDatabase(), export);
        await db.close();

        db = await factory.openDatabase('test');
        expect(await record.get(db), 'value');
        await record.put(db, 'value2');
        expect(await record.get(db), 'value2');
        await db.close();
      });
      test('import', () async {
        var store = StoreRef<String, String>.main();
        var record = store.record('key');
        await factory.deleteDatabase('test');
        await sdbImportDatabase(export, jdbFactoryIdb.idbFactory, 'test');

        var db = await factory.openDatabase('test');
        expect(await record.get(db), 'value');
        await record.put(db, 'value');
        expect(await record.get(db), 'value');
        await db.close();
      });
    });
  });
}
