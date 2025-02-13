library;

import 'dart:async';
import 'dart:convert';

import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/sembast_fs.dart';

import 'test_common.dart';
import 'test_common_impl.dart';

void main() {
  defineTests(memoryFileSystemContext);
}

void defineTests(FileSystemTestContext ctx) {
  final fs = ctx.fs;
  DatabaseFactory factory = DatabaseFactoryFs(fs);
  String? dbPath;

  Future<String?> prepareForDb() async {
    dbPath = dbPathFromName('compat/database_impl_format.db');
    await factory.deleteDatabase(dbPath!);
    // await fs.file(dbPath).delete().catchError((_) {});
    return dbPath;
  }

  group('exportStat', () {
    setUp(() async {
      await prepareForDb();
    });

    var store = StoreRef<int, String>.main();
    var record = store.record(1);

    test('add/put/delete', () async {
      final db = await factory.openDatabase(dbPath!) as SembastDatabase;
      await record.put(db, 'test1');

      var exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 0);
      expect(exportStat.lineCount, 2);
      expect(exportStat.obsoleteLineCount, 0);

      // put same
      await record.put(db, 'test1');

      exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 0);
      expect(exportStat.lineCount, 3);
      expect(exportStat.obsoleteLineCount, 1);

      // delete
      await record.delete(db);

      exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 0);
      expect(exportStat.lineCount, 4);
      expect(exportStat.obsoleteLineCount, 2);
    });
  });

  group('compact', () {
    var store = StoreRef<int, String>.main();

    test('compact_and_write', () async {
      await prepareForDb();
      final db = await factory.openDatabase(dbPath!);
      await store.record(1).put(db, 'test1');
      await db.compact();
      await store.record(2).put(db, 'test2');
      await db.close();
      final lines = await readContent(fs, dbPath!);
      expect(lines.length, 3);
      expect(json.decode(lines[1]), {'key': 1, 'value': 'test1'});
      expect(json.decode(lines[2]), {'key': 2, 'value': 'test2'});
    });

    test('compact_and_reopen', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath!) as SembastDatabase;
      await store.record(1).put(db, 'test1');
      await db.compact();
      db = await db.reOpen() as SembastDatabase;
      await store.record(2).put(db, 'test2');
      await db.close();
      final lines = await readContent(fs, dbPath!);
      expect(lines.length, 3);
      expect(json.decode(lines[1]), {'key': 1, 'value': 'test1'});
      expect(json.decode(lines[2]), {'key': 2, 'value': 'test2'});
    });

    // tmp
    test('twice same record', () async {
      await prepareForDb();
      final db = await factory.openDatabase(dbPath!) as SembastDatabase;
      await store.record(1).put(db, 'hi');
      await store.record(1).put(db, 'hi');
      await db.compact();
      await db.flush();
      var lines = await readContent(fs, dbPath!);
      expect(lines.length, 2);
      expect(json.decode(lines[1]), {'key': 1, 'value': 'hi'});
      await db.close();
    });
  });

  group('format_import', () {
    var store = StoreRef<int, int>.main();
    test('open_no_compact', () async {
      await prepareForDb();
      final line = json.encode({'key': 1, 'value': 2});
      // Compact is needed after 6 times the same record
      await writeContent(fs, dbPath!, [
        json.encode({'version': 2, 'sembast': 1}),
        line,
        line,
        line,
        line,
        line,
        line,
      ]);
      final db = await factory.openDatabase(dbPath!) as SembastDatabase;
      expect(await store.record(1).get(db), 2);
      final lines = await readContent(fs, dbPath!);
      expect(lines.length, 7);

      final exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 0);
      expect(exportStat.lineCount, 7);
      expect(exportStat.obsoleteLineCount, 5);
    });

    test('open_compact', () async {
      await prepareForDb();
      final line = json.encode({'key': 1, 'value': 2});
      // Compact is needed after 6 times the same record
      await writeContent(fs, dbPath!, [
        json.encode({'version': 2, 'sembast': 1}),
        line,
        line,
        line,
        line,
        line,
        line,
        line,
      ]);
      final db = await factory.openDatabase(dbPath!) as SembastDatabase;
      expect(await store.record(1).get(db), 2);
      final lines = await readContent(fs, dbPath!);
      expect(lines.length, 2);

      //devPrintJson(db.toJson());
      final exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 1);
      expect(exportStat.lineCount, 2);
      expect(exportStat.obsoleteLineCount, 0);
    });
  });
}
