library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:sembast/blob.dart';
import 'package:sembast/src/api/protected/database.dart';
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
      await db.close();

      expect(export, expectedExport);
      // make sure it is json encodable
      expect(jsonEncode(export), startsWith('{'));

      // import and reexport to test content
      final importDbPath = dbPathFromName('compat/import_export.db');
      var importedDb = await importDatabase(export, ctx.factory, importDbPath,
          codec: db.sembastCodec);
      expect(await exportDatabase(importedDb), expectedExport);

      await importedDb.close();

      // json round trip and export
      var jsonExport = json.encode(export);
      export = (json.decode(jsonExport) as Map).cast<String, Object?>();
      importedDb = await importDatabase(export, ctx.factory, importDbPath);
      expect(await exportDatabase(importedDb), expectedExport);
      await importedDb.close();
    }

    Future<void> checkExportImportLines(
        Database db, List expectedExport) async {
      List export = await exportDatabaseLines(db);
      await db.close();

      expect(export, expectedExport);
      // make sure it is json encodable
      expect(jsonEncode(export), startsWith('['));

      // import and reexport to test content
      final importDbPath = dbPathFromName('compat/import_export_lines.db');
      var importedDb =
          await importDatabaseLines(export, ctx.factory, importDbPath);
      expect(await exportDatabaseLines(importedDb), expectedExport);

      await importedDb.close();

      // json round trip and export
      var jsonExport = json.encode(export);
      export = (json.decode(jsonExport) as List);
      importedDb = await importDatabaseLines(export, ctx.factory, importDbPath);
      expect(await exportDatabaseLines(importedDb), expectedExport);
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
      await checkExportImportLines(db, [
        {'sembast_export': 1, 'version': 1},
        {'store': '_main'},
        [1, 'hi']
      ]);
    });

    test('1_string_record_with_codec', () async {
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
      await checkExportImportLines(db, [
        {'sembast_export': 1, 'version': 1},
        {'store': '_main'},
        [1, 'hi']
      ]);
    });

    test('1_deleted_record', () async {
      final db =
          await setupForTest(ctx, 'compat/import_export/1_deleted_record.db');
      var record = store.record(1);
      await record.put(db, 'hi');
      await record.delete(db);
      // deleted record not exported
      await checkExportImport(db, {'sembast_export': 1, 'version': 1});
      await checkExportImportLines(db, [
        {'sembast_export': 1, 'version': 1},
      ]);
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
      await checkExportImportLines(db, [
        {'sembast_export': 1, 'version': 1},
        {'store': '_main'},
        [1, 'hi'],
        {'store': 'store2'},
        [1, 'hi'],
        {'store': 'store3'},
        [1, 'hi']
      ]);
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
      await checkExportImportLines(db, [
        {'sembast_export': 1, 'version': 1},
        {'store': '_main'},
        [1, 'hu'],
        [2, 'ha'],
        [3, 'ho']
      ]);
    });

    test('1_map_record', () async {
      final db =
          await setupForTest(ctx, 'compat/import_export/1_map_record.db');

      var store = intMapStoreFactory.store();
      await store.record(1).put(db, {'test': 2});

      await checkExportImport(db, {
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

    test('1_map_record_with_all_types', () async {
      final db = await setupForTest(
          ctx, 'compat/import_export/1_map_record_with_all_types.db');

      var store = stringMapStoreFactory.store();
      await store.record('my_key').put(db, {
        'my_bool': true,
        'my_date': Timestamp(123456789012, 567891000),
        'my_int': 1,
        'my_double': 1.5,
        'my_blob': Blob(Uint8List.fromList([1, 2, 3])),
        'my_string': 'some text',
        'my_list': [4, 5, 6],
        'my_map': {'sub': 73},
        'my_complex': [
          {
            'sub': [
              {
                'inner': [7, 8, 9]
              }
            ]
          }
        ],
      });

      await checkExportImport(db, {
        'sembast_export': 1,
        'version': 1,
        'stores': [
          {
            'name': '_main',
            'keys': ['my_key'],
            'values': [
              {
                'my_bool': true,
                'my_date': {'@Timestamp': '5882-03-11T00:30:12.567891Z'},
                'my_int': 1,
                'my_double': 1.5,
                'my_blob': {'@Blob': 'AQID'},
                'my_string': 'some text',
                'my_list': [4, 5, 6],
                'my_map': {'sub': 73},
                'my_complex': [
                  {
                    'sub': [
                      {
                        'inner': [7, 8, 9]
                      }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      });
      await checkExportImportLines(db, [
        {'sembast_export': 1, 'version': 1},
        {'store': '_main'},
        [
          'my_key',
          {
            'my_bool': true,
            'my_date': {'@Timestamp': '5882-03-11T00:30:12.567891Z'},
            'my_int': 1,
            'my_double': 1.5,
            'my_blob': {'@Blob': 'AQID'},
            'my_string': 'some text',
            'my_list': [4, 5, 6],
            'my_map': {'sub': 73},
            'my_complex': [
              {
                'sub': [
                  {
                    'inner': [7, 8, 9]
                  }
                ]
              }
            ]
          }
        ]
      ]);
    });
  });
}
