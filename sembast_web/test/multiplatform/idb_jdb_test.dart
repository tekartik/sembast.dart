library;

import 'package:idb_shim/utils/idb_import_export.dart';
import 'package:sembast/sembast.dart' as sembast;
import 'package:sembast_web/src/jdb_database_idb.dart' show JdbDatabaseIdb;
import 'package:sembast_web/src/jdb_factory_idb.dart' show JdbFactoryIdb;
import 'package:sembast_web/src/jdb_import.dart';
import 'package:test/test.dart';

import '../base64_codec.dart';

DatabaseFactoryJdb asDatabaseFactoryIdb(
  sembast.DatabaseFactory databaseFactory,
) => databaseFactory as DatabaseFactoryJdb;

JdbFactoryIdb asJdbJactoryIdb(JdbFactory factory) => factory as JdbFactoryIdb;

SembastDatabase asSembastDatabase(sembast.Database db) => db as SembastDatabase;

SembastStorageJdb? asSembastStorateJdb(StorageJdb? storageJdb) =>
    storageJdb as SembastStorageJdb?;

JdbDatabaseIdb? asJsbDatabaseIdb(JdbDatabase? database) =>
    database as JdbDatabaseIdb?;

JdbDatabaseIdb? dbAsJsbDatabaseIdb(sembast.Database db) => asJsbDatabaseIdb(
  asSembastStorateJdb(asSembastDatabase(db).storageJdb)!.jdbDatabase,
);

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
                  {'name': 'deleted', 'keyPath': 'deleted', 'multiEntry': true},
                  {
                    'name': 'record',
                    'keyPath': ['store', 'key'],
                  },
                ],
              },
              {'name': 'info'},
              ['entry', 'info'],
              2,
            ],
          },
          {
            'name': 'entry',
            'keys': [1],
            'values': [
              {'store': '_main', 'key': 'key', 'value': 'value'},
            ],
          },
          {
            'name': 'info',
            'keys': ['meta', 'revision'],
            'values': [
              {'version': 1, 'sembast': 1},
              1,
            ],
          },
        ],
      };

      test('export', () async {
        var store = sembast.StoreRef<String, String>.main();
        var record = store.record('key');
        await factory.deleteDatabase('test');
        var db = await factory.openDatabase('test');
        expect(await record.get(db), isNull);
        await record.put(db, 'value');
        expect(await record.get(db), 'value');
        expect(await dbAsJsbDatabaseIdb(db)!.sdbExportDatabase(), export);
        await db.close();

        db = await factory.openDatabase('test');
        expect(await record.get(db), 'value');
        expect(await dbAsJsbDatabaseIdb(db)!.sdbExportDatabase(), export);
        await record.put(db, 'value2');
        expect(await record.get(db), 'value2');
        await db.close();
      });

      test('import/close open', () async {
        var dbName = 'test_import.db';
        var store = sembast.StoreRef<String, String>.main();
        var record = store.record('key');
        await factory.deleteDatabase(dbName);

        var sdb = await sdbImportDatabase(
          export,
          jdbFactoryIdb.idbFactory,
          dbName,
        );

        sdb.close();

        var db = await factory.openDatabase(dbName);
        expect(await record.get(db), 'value');
        await record.put(db, 'value');
        expect(await record.get(db), 'value');
        await db.close();
      }, skip: true);
    });

    group('codec_export', () {
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
                  {'name': 'deleted', 'keyPath': 'deleted', 'multiEntry': true},
                  {
                    'name': 'record',
                    'keyPath': ['store', 'key'],
                  },
                ],
              },
              {'name': 'info'},
              ['entry', 'info'],
              2,
            ],
          },
          {
            'name': 'entry',
            'keys': [1],
            'values': [
              {'store': '_main', 'key': 'key', 'value': 'InZhbHVlIg=='},
            ],
          },
          {
            'name': 'info',
            'keys': ['meta', 'revision'],
            'values': [
              {
                'version': 1,
                'sembast': 1,
                'codec': 'eyJzaWduYXR1cmUiOiJiYXNlNjQifQ==',
              },
              1,
            ],
          },
        ],
      };

      test('export', () async {
        var codec = sembast.SembastCodec(
          signature: 'base64',
          codec: SembastBase64Codec(),
        );
        var store = sembast.StoreRef<String, String>.main();
        var record = store.record('key');
        await factory.deleteDatabase('test');
        var db = await factory.openDatabase('test', codec: codec);
        expect(await record.get(db), isNull);
        await record.put(db, 'value');
        expect(await record.get(db), 'value');
        expect(await dbAsJsbDatabaseIdb(db)!.sdbExportDatabase(), export);
        await db.close();

        db = await factory.openDatabase('test', codec: codec);
        expect(await record.get(db), 'value');
        expect(await dbAsJsbDatabaseIdb(db)!.sdbExportDatabase(), export);
        await record.put(db, 'value2');
        expect(await record.get(db), 'value2');
        await db.close();
      });

      test('async codec', () async {
        var codec = sembast.SembastCodec(
          signature: 'base64',
          codec: SembastBase64CodecAsync(),
        );
        var store = sembast.StoreRef<String, String>.main();
        var record = store.record('key');
        await factory.deleteDatabase('test');
        var db = await factory.openDatabase('test', codec: codec);
        expect(await record.get(db), isNull);
        await record.put(db, 'value');
        expect(await record.get(db), 'value');
        expect(await dbAsJsbDatabaseIdb(db)!.sdbExportDatabase(), export);
        await db.close();

        db = await factory.openDatabase('test', codec: codec);
        expect(await record.get(db), 'value');
        expect(await dbAsJsbDatabaseIdb(db)!.sdbExportDatabase(), export);
        await record.put(db, 'value2');
        expect(await record.get(db), 'value2');
        await db.close();
      });

      test('import/close open', () async {
        var dbName = 'test_import.db';
        var store = sembast.StoreRef<String, String>.main();
        var record = store.record('key');
        await factory.deleteDatabase(dbName);

        var sdb = await sdbImportDatabase(
          export,
          jdbFactoryIdb.idbFactory,
          dbName,
        );

        sdb.close();

        var db = await factory.openDatabase(dbName);
        expect(await record.get(db), 'value');
        await record.put(db, 'value');
        expect(await record.get(db), 'value');
        await db.close();
      }, skip: true);
    });
  });
}
