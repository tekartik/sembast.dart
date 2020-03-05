library sembast.database_import_export_test;

import 'dart:async';
import 'dart:convert';

import 'package:sembast/utils/sembast_import_export.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('import_export', () {
    tearDown(() {});

    Future _checkExportImport(Database db, Map expectedExport) async {
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
      export = (json.decode(jsonExport) as Map)?.cast<String, dynamic>();
      importedDb = await importDatabase(export, ctx.factory, importDbPath);
      expect(await exportDatabase(importedDb), expectedExport);
      await importedDb.close();
    }

    test('no_version', () async {
      var db = await setupForTest(ctx, 'compat/import_export/no_version.db');
      await _checkExportImport(db, {'sembast_export': 1, 'version': 1});
    });

    test('version_2', () async {
      final db = await ctx.open(
          dbPathFromName('compat/import_export/version_2.db'),
          version: 2);
      await _checkExportImport(db, {'sembast_export': 1, 'version': 2});
    });

    var store = StoreRef<int, String>.main();
    test('1_string_record', () async {
      final db =
          await setupForTest(ctx, 'compat/import_export/1_string_record.db');
      await store.record(1).put(db, 'hi');
      await _checkExportImport(db, {
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

    test('1_deleted_record', () async {
      final db =
          await setupForTest(ctx, 'compat/import_export/1_deleted_record.db');
      var record = store.record(1);
      await record.put(db, 'hi');
      await record.delete(db);
      // deleted record not exported
      await _checkExportImport(db, {'sembast_export': 1, 'version': 1});
    });

    test('twice_same_record', () async {
      final db =
          await setupForTest(ctx, 'compat/import_export/twice_same_record.db');
      await store.record(1).put(db, 'hi');
      await store.record(1).put(db, 'hi');
      await _checkExportImport(db, {
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

    test('1_map_record', () async {
      final db =
          await setupForTest(ctx, 'compat/import_export/1_map_record.db');

      var store = intMapStoreFactory.store();
      await store.record(1).put(db, {'test': 2});

      await _checkExportImport(db, {
        'sembast_export': 1,
        'version': 1,
        'stores': [
          {
            'name': '_main',
            'keys': [1],
            'values': [
              {'test': 2}
            ]
          }
        ]
      });
    });
  });
}
