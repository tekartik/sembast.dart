library sembast.database_import_export_test;

import 'dart:async';
import 'dart:convert';

import 'package:sembast/sembast.dart';
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
      String importDbPath = ctx.dbPath + "_import.db";
      Database importedDb =
          await importDatabase(export, ctx.factory, importDbPath);
      expect(await exportDatabase(importedDb), expectedExport);

      await importedDb.close();

      // json round trip and export
      var jsonExport = json.encode(export);
      export = json.decode(jsonExport) as Map;
      importedDb = await importDatabase(export, ctx.factory, importDbPath);
      expect(await exportDatabase(importedDb), expectedExport);
    }

    test('no_version', () async {
      Database db = await ctx.open();
      await _checkExportImport(db, {'sembast_export': 1, 'version': 1});
    });

    test('version_2', () async {
      Database db = await ctx.open(2);
      await _checkExportImport(db, {'sembast_export': 1, 'version': 2});
    });

    test('1_string_record', () async {
      Database db = await ctx.open();
      await db.put("hi", 1);
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
      Database db = await ctx.open();
      await db.delete(await db.put("hi", 1));
      // deleted record not exported
      await _checkExportImport(db, {'sembast_export': 1, 'version': 1});
    });

    test('1_record_in_2_stores', () async {
      Database db = await ctx.open();
      db.getStore('store1');
      Store store2 = db.getStore('store2');
      await store2.put("hi", 1);
      await _checkExportImport(db, {
        'sembast_export': 1,
        'version': 1,
        'stores': [
          {
            'name': 'store2',
            'keys': [1],
            'values': ['hi']
          }
        ]
      });
    });

    test('twice_same_record', () async {
      Database db = await ctx.open();
      await db.put("hi", 1);
      await db.put("hi", 1);
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
      Database db = await ctx.open();

      await db.put({'test': 2}, 1);

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
