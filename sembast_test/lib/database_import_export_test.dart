library sembast.database_import_export_test;

import 'dart:async';
import 'dart:convert';

import 'package:sembast/timestamp.dart';
import 'package:sembast/utils/sembast_import_export.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('import_export', () {
    tearDown(() {});

    Future checkExportImport(Database db, Map expectedExport) async {
      var export = await exportDatabase(db);
      expect(export, expectedExport);
      await db.close();

      // import and reexport to test content
      final importDbPath = dbPathFromName('compat/import_export.db');
      var importedDb = await importDatabase(export, ctx.factory, importDbPath);
      expect(await exportDatabase(importedDb), expectedExport);

      await importedDb.close();

      // json round trip and export
      var jsonExport = json.encode(export);
      export = (json.decode(jsonExport) as Map).cast<String, Object?>();
      importedDb = await importDatabase(export, ctx.factory, importDbPath);
      expect(await exportDatabase(importedDb), expectedExport);
      await importedDb.close();

      // Reopen normal no version
      importedDb = await ctx.factory.openDatabase(importDbPath);
      expect(await exportDatabase(importedDb), expectedExport);
      await importedDb.close();
    }

    test('no_version', () async {
      var db = await setupForTest(ctx, 'compat/import_export/no_version.db');
      await checkExportImport(db, {'sembast_export': 1, 'version': 1});
    });

    test('version_2', () async {
      final db = await ctx.open(
          dbPathFromName('compat/import_export/version_2.db'),
          version: 2);
      await checkExportImport(db, {'sembast_export': 1, 'version': 2});
    });

    var store = StoreRef<int, String>.main();
    test('1_string_record', () async {
      final db =
          await setupForTest(ctx, 'compat/import_export/1_string_record.db');
      await store.record(1).put(db, 'hi');
      await checkExportImport(db, {
        'sembast_export': 1,
        'version': 1,
        'stores': [
          {
            'name': '_main',
            'keys': [1],
            'values': ['hi']
          }
        ]
      });
    });

    test('1_string_record_no_cooperator', () async {
      disableSembastCooperator();
      try {
        final db = await setupForTest(
            ctx, 'compat/import_export/1_string_record_no_cooperator.db');
        await store.record(1).put(db, 'hi');
        await checkExportImport(db, {
          'sembast_export': 1,
          'version': 1,
          'stores': [
            {
              'name': '_main',
              'keys': [1],
              'values': ['hi']
            }
          ]
        });
      } finally {
        enableSembastCooperator();
      }
    });

    test('1_deleted_record', () async {
      final db =
          await setupForTest(ctx, 'compat/import_export/1_deleted_record.db');
      var record = store.record(1);
      await record.put(db, 'hi');
      await record.delete(db);
      // deleted record not exported
      await checkExportImport(db, {'sembast_export': 1, 'version': 1});
    });

    test('twice_same_record', () async {
      final db =
          await setupForTest(ctx, 'compat/import_export/twice_same_record.db');
      await store.record(1).put(db, 'hi');
      await store.record(1).put(db, 'hi');
      await checkExportImport(db, {
        'sembast_export': 1,
        'version': 1,
        'stores': [
          {
            'name': '_main',
            'keys': [1],
            'values': ['hi']
          }
        ]
      });
    });

    test('three_stores', () async {
      final db =
          await setupForTest(ctx, 'compat/import_export/three_stores.db');
      var store2 = StoreRef<int, String>('store2');
      var store3 = StoreRef<int, String>('store3');
      // Put 3 first to test order
      await store3.record(1).put(db, 'hi');
      await store.record(1).put(db, 'hi');
      await store2.record(1).put(db, 'hi');

      await checkExportImport(db, {
        'sembast_export': 1,
        'version': 1,
        'stores': [
          {
            'name': '_main',
            'keys': [1],
            'values': ['hi']
          },
          {
            'name': 'store2',
            'keys': [1],
            'values': ['hi']
          },
          {
            'name': 'store3',
            'keys': [1],
            'values': ['hi']
          }
        ]
      });

      var filteredExport = {
        'sembast_export': 1,
        'version': 1,
        'stores': [
          {
            'name': 'store2',
            'keys': [1],
            'values': ['hi']
          },
        ]
      };
      // export with storeNames
      expect(await exportDatabase(db, storeNames: ['store2']), filteredExport);

      // import with storeName
      var exportMap = await exportDatabase(db);

      final importDbPath = dbPathFromName('imported_with_store_names.db');
      var importedDb = await importDatabase(
          exportMap, ctx.factory, importDbPath,
          storeNames: ['store2']);
      // Check imported data by exporting all
      expect(await exportDatabase(importedDb), filteredExport);
      await importedDb.close();
    });

    test('three_records', () async {
      final db =
          await setupForTest(ctx, 'compat/import_export/three_records.db');
      // Put 3 first to test order
      await store.record(3).put(db, 'ho');
      await store.record(1).put(db, 'hu');
      await store.record(2).put(db, 'ha');

      await checkExportImport(db, {
        'sembast_export': 1,
        'version': 1,
        'stores': [
          {
            'name': '_main',
            'keys': [1, 2, 3],
            'values': ['hu', 'ha', 'ho']
          }
        ]
      });
    });

    test('1_map_record', () async {
      final db =
          await setupForTest(ctx, 'compat/import_export/1_map_record.db');

      var store = intMapStoreFactory.store();
      await store.record(1).put(db, {'test': 2, 'timestamp': Timestamp(1, 2)});

      await checkExportImport(db, {
        'sembast_export': 1,
        'version': 1,
        'stores': [
          {
            'name': '_main',
            'keys': [1],
            'values': [
              {
                'test': 2,
                'timestamp': {'@Timestamp': '1970-01-01T00:00:01.000000002Z'}
              }
            ]
          }
        ]
      });
    });
  });
}
