library;

import 'dart:async';

// ignore: implementation_imports
import 'package:sembast/src/api/protected/database.dart';
import 'package:sembast/timestamp.dart';
import 'package:sembast/utils/sembast_import_export.dart';
import 'package:sembast_test/test_codecs.dart';

import 'src/import_common.dart';
import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('import_export', () {
    tearDown(() {});

    Future<void> checkExportImportLines(
      Database db,
      List expectedExport,
    ) async {
      var codec = db.sembastCodec;
      List export = await exportDatabaseLines(db);
      await db.close();

      expect(export, expectedExport);
      // make sure it is json encodable
      expect(jsonEncode(export), startsWith('['));

      // import and reexport to test content
      final importDbPath = dbPathFromName('compat/import_export_lines.db');
      var importedDb = await importDatabaseLines(
        export,
        ctx.factory,
        importDbPath,
        codec: codec,
      );
      expect(await exportDatabaseLines(importedDb), expectedExport);

      await importedDb.close();

      // json round trip and export
      var jsonExport = json.encode(export);
      export = (json.decode(jsonExport) as List);
      importedDb = await importDatabaseLines(
        export,
        ctx.factory,
        importDbPath,
        codec: codec,
      );
      expect(await exportDatabaseLines(importedDb), expectedExport);
      expect(importedDb.sembastCodec, codec);
      await importedDb.close();
    }

    Future checkExportImport(Database db, Map expectedExport) async {
      var codec = db.sembastCodec;
      var export = await exportDatabase(db);
      expect(export, expectedExport);
      await db.close();
      // make sure it is json encodable
      expect(jsonEncode(export), startsWith('{'));
      // import and reexport to test content
      final importDbPath = dbPathFromName('compat/import_export.db');
      var importedDb = await importDatabase(
        export,
        ctx.factory,
        importDbPath,
        codec: codec,
      );
      expect(await exportDatabase(importedDb), expectedExport);

      await importedDb.close();

      // json round trip and export
      var jsonExport = json.encode(export);
      export = (json.decode(jsonExport) as Map).cast<String, Object?>();
      importedDb = await importDatabase(
        export,
        ctx.factory,
        importDbPath,
        codec: codec,
      );
      expect(await exportDatabase(importedDb), expectedExport);
      await importedDb.close();

      // Reopen normal no version
      importedDb = await ctx.factory.openDatabase(importDbPath, codec: codec);
      expect(await exportDatabase(importedDb), expectedExport);
      expect(importedDb.sembastCodec, codec);
      await importedDb.close();
    }

    test('no_version', () async {
      var db = await setupForTest(ctx, 'compat/import_export/no_version.db');
      await checkExportImport(db, {'sembast_export': 1, 'version': 1});
    });

    test('version_2', () async {
      final db = await ctx.deleteAndOpen(
        dbPathFromName('compat/import_export/version_2.db'),
        version: 2,
      );
      await checkExportImport(db, {'sembast_export': 1, 'version': 2});
    });

    var store = StoreRef<int, String>.main();
    test('1_string_record', () async {
      final db = await setupForTest(
        ctx,
        'compat/import_export/1_string_record.db',
      );
      await store.record(1).put(db, 'hi');
      await checkExportImport(db, {
        'sembast_export': 1,
        'version': 1,
        'stores': [
          {
            'name': '_main',
            'keys': [1],
            'values': ['hi'],
          },
        ],
      });
    });

    test('1_string_record_with_codec', () async {
      var codec = SembastCodec(signature: 'custom', codec: MyCustomCodec());
      final db = await setupForTest(
        ctx,
        'compat/import_export/1_string_record.db',
        codec: codec,
      );
      expect(db.sembastCodec, codec);
      await store.record(1).put(db, 'hi');
      await checkExportImport(db, {
        'sembast_export': 1,
        'version': 1,
        'stores': [
          {
            'name': '_main',
            'keys': [1],
            'values': ['hi'],
          },
        ],
      });
      await checkExportImportLines(db, [
        {'sembast_export': 1, 'version': 1},
        {'store': '_main'},
        [1, 'hi'],
      ]);
    });

    test('1_string_record_no_cooperator', () async {
      disableSembastCooperator();
      try {
        final db = await setupForTest(
          ctx,
          'compat/import_export/1_string_record_no_cooperator.db',
        );
        await store.record(1).put(db, 'hi');
        await checkExportImport(db, {
          'sembast_export': 1,
          'version': 1,
          'stores': [
            {
              'name': '_main',
              'keys': [1],
              'values': ['hi'],
            },
          ],
        });
      } finally {
        enableSembastCooperator();
      }
    });

    test('1_deleted_record', () async {
      final db = await setupForTest(
        ctx,
        'compat/import_export/1_deleted_record.db',
      );
      var record = store.record(1);
      await record.put(db, 'hi');
      await record.delete(db);
      // deleted record not exported
      await checkExportImport(db, {'sembast_export': 1, 'version': 1});
    });

    test('twice_same_record', () async {
      final db = await setupForTest(
        ctx,
        'compat/import_export/twice_same_record.db',
      );
      await store.record(1).put(db, 'hi');
      await store.record(1).put(db, 'hi');
      await checkExportImport(db, {
        'sembast_export': 1,
        'version': 1,
        'stores': [
          {
            'name': '_main',
            'keys': [1],
            'values': ['hi'],
          },
        ],
      });
    });

    test('three_stores', () async {
      final db = await setupForTest(
        ctx,
        'compat/import_export/three_stores.db',
      );
      var store2 = StoreRef<int, String>('store2');
      var store3 = StoreRef<int, String>('store3');
      // Put 3 first to test order
      await store3.record(1).put(db, 'hi');
      await store.record(1).put(db, 'hi');
      await store2.record(1).put(db, 'hi');

      var exportLines = await exportDatabaseLines(db);
      await checkExportImport(db, {
        'sembast_export': 1,
        'version': 1,
        'stores': [
          {
            'name': '_main',
            'keys': [1],
            'values': ['hi'],
          },
          {
            'name': 'store2',
            'keys': [1],
            'values': ['hi'],
          },
          {
            'name': 'store3',
            'keys': [1],
            'values': ['hi'],
          },
        ],
      });
      expect(exportLines, [
        {'sembast_export': 1, 'version': 1},
        {'store': '_main'},
        [1, 'hi'],
        {'store': 'store2'},
        [1, 'hi'],
        {'store': 'store3'},
        [1, 'hi'],
      ]);

      var filteredExport = {
        'sembast_export': 1,
        'version': 1,
        'stores': [
          {
            'name': 'store2',
            'keys': [1],
            'values': ['hi'],
          },
        ],
      };
      var filteredExportLines = [
        {'sembast_export': 1, 'version': 1},
        {'store': 'store2'},
        [1, 'hi'],
      ];
      // export with storeNames
      expect(await exportDatabase(db, storeNames: ['store2']), filteredExport);
      // export with storeNames
      expect(
        await exportDatabaseLines(db, storeNames: ['store2']),
        filteredExportLines,
      );

      // import with storeName
      var exportMap = await exportDatabase(db);

      final importDbPath = dbPathFromName('imported_with_store_names.db');
      var importedDb = await importDatabase(
        exportMap,
        ctx.factory,
        importDbPath,
        storeNames: ['store2'],
      );
      // Check imported data by exporting all
      expect(await exportDatabase(importedDb), filteredExport);
      await importedDb.close();

      importedDb = await importDatabaseLines(
        exportLines,
        ctx.factory,
        importDbPath,
        storeNames: ['store2'],
      );
      // Check imported data by exporting all
      expect(await exportDatabaseLines(importedDb), filteredExportLines);
      await importedDb.close();
    });

    test('three_records', () async {
      final db = await setupForTest(
        ctx,
        'compat/import_export/three_records.db',
      );
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
            'values': ['hu', 'ha', 'ho'],
          },
        ],
      });
    });

    test('1_map_record', () async {
      final db = await setupForTest(
        ctx,
        'compat/import_export/1_map_record.db',
      );

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
                'timestamp': {'@Timestamp': '1970-01-01T00:00:01.000000002Z'},
              },
            ],
          },
        ],
      });
    });

    test('import_skip_null', () async {
      var exportLines = [
        {'sembast_export': 1, 'version': 1},
        {'store': '_main'},
        [3, 'ho'],
        [1, 'hi'],
        [2, null],
      ];

      var dbPath = await deleteForTest(
        ctx,
        'compat/import_export/import_skip_null.db',
      );
      var db = await importDatabaseLines(exportLines, ctx.factory, dbPath);
      var export = await exportDatabaseLines(db);
      expect(export.skip(2), [
        [1, 'hi'],
        [3, 'ho'],
      ]);
      await checkExportImportLines(db, export);
    });
    test('any_import', () async {
      var dbPath = await deleteForTest(
        ctx,
        'compat/import_export/any_import.db',
      );
      Future<void> checkDb(Database db) async {
        expect(await exportDatabaseLines(db), [
          {'sembast_export': 1, 'version': 3},
          {'store': '_main'},
          [1, 'hi'],
        ]);
      }

      Future<void> testImport(Object any) async {
        var db = await importDatabaseAny(any, ctx.factory, dbPath);
        await checkDb(db);
        await db.close();
      }

      var exportLines = [
        {'sembast_export': 1, 'version': 3},
        {'store': '_main'},
        [1, 'hi'],
      ];
      var exportMap = {
        'sembast_export': 1,
        'version': 3,
        'stores': [
          {
            'name': '_main',
            'keys': [1],
            'values': ['hi'],
          },
        ],
      };
      await testImport(exportLines);
      await testImport(jsonEncode(exportLines));
      await testImport(jsonEncode(exportLines));
      await testImport(jsonEncode(exportLines));
      await testImport(exportLinesToJsonStringList(exportLines));
      await testImport(exportLines);
      await testImport(exportLines);
      await testImport(exportLines);
      await testImport(exportLines);
      await testImport(exportLines);
      await testImport(exportLines);
      await testImport(exportLines);
      await testImport(exportLinesToJsonStringList(exportLines).join('\n'));
      await testImport(exportMap);
      await testImport(jsonEncode(exportMap));
    });

    test('exportLinesToJsonStringList', () {
      expect(
        exportLinesToJsonStringList([
          {'b': 2, 'a': 1},
          [
            1,
            {'b': 2, 'a': 1},
          ],
        ]),
        ['{"a":1,"b":2}', '[1,{"a":1,"b":2}]'],
      );
    });
    test('any_import_empty', () async {
      var dbPath = await deleteForTest(
        ctx,
        'compat/import_export/any_import_empty.db',
      );
      Future<void> checkDb(Database db) async {
        expect(await exportDatabaseLines(db), [
          {'sembast_export': 1, 'version': 2},
        ]);
      }

      Future<void> testImport(Object any) async {
        var db = await importDatabaseAny(any, ctx.factory, dbPath);
        await checkDb(db);
        await db.close();
      }

      var exportLines = [
        {'sembast_export': 1, 'version': 2},
      ];
      var exportMap = {'sembast_export': 1, 'version': 2};
      await testImport(exportLines);
      await testImport(jsonEncode(exportLines));
      await testImport(exportLinesToJsonStringList(exportLines));
      await testImport(exportLinesToJsonStringList(exportLines).join('\n'));
      await testImport(exportMap);
      await testImport(jsonEncode(exportMap));
    });
  });
}
