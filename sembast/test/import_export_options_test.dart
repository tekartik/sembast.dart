library;

import 'package:sembast/sembast_memory.dart';
import 'package:sembast/utils/sembast_import_export.dart';
import 'package:test/test.dart';

void main() {
  group('import_export_options', () {
    const at = SembastExportTypeEncoding.at;
    const dollar = SembastExportTypeEncoding.dollar;

    test('copyWith', () {
      var export = const SembastExportOptions(storeNames: ['a']);
      var exportCopy = export.copyWith(typeEncoding: dollar);
      expect(exportCopy.storeNames, ['a']);
      expect(exportCopy.typeEncoding, dollar);
      expect(exportCopy.copyWith(storeNames: ['b']).typeEncoding, dollar);
      expect(exportCopy.copyWith(storeNames: ['b']).storeNames, ['b']);

      var import = const SembastImportOptions(storeNames: ['a']);
      var importCopy = import.copyWith(allowedTypeEncodings: [at]);
      expect(importCopy.storeNames, ['a']);
      expect(importCopy.allowedTypeEncodings, [at]);
      expect(importCopy.copyWith(storeNames: ['b']).allowedTypeEncodings, [at]);
    });

    group('storeNames', () {
      var a = StoreRef<int, String>('a');
      var b = StoreRef<int, String>('b');
      late Database db;
      setUp(() async {
        db = await newDatabaseFactoryMemory().openDatabase('options.db');
        await a.record(1).put(db, 'a1');
        await b.record(1).put(db, 'b1');
      });
      tearDown(() async {
        await db.close();
      });

      /// The exported store names.
      List<String?> stores(List<Object> lines) => [
        for (var line in lines)
          if (line is Map && line['store'] is String) line['store'] as String,
      ];

      test('export', () async {
        expect(stores(await exportDatabaseLines(db)), ['a', 'b']);
        // The argument, still supported.
        expect(stores(await exportDatabaseLines(db, storeNames: ['a'])), ['a']);
        // The options override it.
        expect(
          stores(
            await exportDatabaseLines(
              db,
              storeNames: ['a'],
              options: const SembastExportOptions(storeNames: ['b']),
            ),
          ),
          ['b'],
        );
        // Options without store names keep the argument.
        expect(
          stores(
            await exportDatabaseLines(
              db,
              storeNames: ['a'],
              options: const SembastExportOptions(typeEncoding: dollar),
            ),
          ),
          ['a'],
        );
        var map = await exportDatabase(
          db,
          storeNames: ['a'],
          options: const SembastExportOptions(storeNames: ['b']),
        );
        expect((map['stores'] as List).map((e) => (e as Map)['name']), ['b']);
      });

      test('import', () async {
        var lines = await exportDatabaseLines(db);
        Future<List<String?>> importedStores({
          List<String>? storeNames,
          SembastImportOptions? options,
        }) async {
          var imported = await importDatabaseLines(
            lines,
            newDatabaseFactoryMemory(),
            'imported.db',
            storeNames: storeNames,
            options: options,
          );
          try {
            return stores(await exportDatabaseLines(imported));
          } finally {
            await imported.close();
          }
        }

        expect(await importedStores(), ['a', 'b']);
        expect(await importedStores(storeNames: ['a']), ['a']);
        expect(
          await importedStores(
            storeNames: ['a'],
            options: const SembastImportOptions(storeNames: ['b']),
          ),
          ['b'],
        );
        expect(
          await importedStores(
            storeNames: ['a'],
            options: const SembastImportOptions(allowedTypeEncodings: [at]),
          ),
          ['a'],
        );
      });
    });
  });
}
