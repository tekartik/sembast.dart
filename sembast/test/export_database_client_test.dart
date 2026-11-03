library;

import 'package:sembast/sembast_memory.dart';
import 'package:sembast/utils/sembast_import_export.dart';
import 'package:test/test.dart';

/// Export with a database client: a database or a transaction.
void main() {
  group('export_database_client', () {
    var store = StoreRef<int, String>('s');
    var otherStore = StoreRef<String, int>('other');
    late Database db;
    setUp(() async {
      db = await newDatabaseFactoryMemory().openDatabase('client.db');
      await store.record(1).put(db, 'one');
      await store.record(2).put(db, 'two');
    });
    tearDown(() async {
      await db.close();
    });

    test('transaction', () async {
      var dbExport = await exportDatabaseLines(db);
      late List<Object> txnExport;
      late List<Object> txnMapExportLines;
      await db.transaction((txn) async {
        // Same as the database before any change.
        expect(await exportDatabaseLines(txn), dbExport);

        // The changes of the transaction are exported.
        await store.record(3).put(txn, 'three');
        await store.record(1).delete(txn);
        await otherStore.record('a').put(txn, 1);
        txnExport = await exportDatabaseLines(txn);
        var map = await exportDatabase(txn);
        txnMapExportLines = [
          {'sembast_export': map['sembast_export'], 'version': map['version']},
          for (var storeMap in map['stores'] as List) ...[
            {'store': (storeMap as Map)['name']},
            for (var i = 0; i < (storeMap['keys'] as List).length; i++)
              [(storeMap['keys'] as List)[i], (storeMap['values'] as List)[i]],
          ],
        ];
      });
      expect(txnExport, [
        {'sembast_export': 1, 'version': 1},
        {'store': 'other'},
        ['a', 1],
        {'store': 's'},
        [2, 'two'],
        [3, 'three'],
      ]);
      expect(txnMapExportLines, txnExport);
      // Committed, the database export is the same.
      expect(await exportDatabaseLines(db), txnExport);
    });

    test('aborted transaction', () async {
      var dbExport = await exportDatabaseLines(db);
      late List<Object> txnExport;
      try {
        await db.transaction((txn) async {
          await store.record(3).put(txn, 'three');
          txnExport = await exportDatabaseLines(txn);
          throw StateError('abort');
        });
      } on StateError catch (_) {}
      expect(txnExport.last, [3, 'three']);
      // Not committed.
      expect(await exportDatabaseLines(db), dbExport);
    });

    test('store names and type encoding', () async {
      await db.transaction((txn) async {
        await otherStore.record('a').put(txn, 1);
        expect(await exportDatabaseLines(txn, storeNames: ['other']), [
          {'sembast_export': 1, 'version': 1},
          {'store': 'other'},
          ['a', 1],
        ]);
        expect(
          (await exportDatabaseLines(
            txn,
            options: const SembastExportOptions(
              typeEncoding: SembastExportTypeEncoding.dollar,
            ),
          )).first,
          {'sembast_export': 1, 'version': 1, 'type_prefix': r'$'},
        );
      });
    });
  });
}
