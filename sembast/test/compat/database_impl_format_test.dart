library sembast.test.compat.database_impl_format_test;

// ignore_for_file: deprecated_member_use_from_same_package
import 'dart:async';
import 'dart:convert';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/sembast_fs.dart';

import '../test_common_impl.dart';
import 'test_common.dart';

void main() {
  defineTests(memoryFileSystemContext);
}

void defineTests(FileSystemTestContext ctx) {
  final fs = ctx.fs;
  DatabaseFactory factory = DatabaseFactoryFs(fs);
  String dbPath;

  Future<String> prepareForDb() async {
    dbPath = dbPathFromName('compat/database_impl_format.db');
    await factory.deleteDatabase(dbPath);
    // await fs.file(dbPath).delete().catchError((_) {});
    return dbPath;
  }

  group('exportStat', () {
    setUp(() async {
      await prepareForDb();
    });

    test('add/put/delete', () async {
      final db = await factory.openDatabase(dbPath) as SembastDatabase;
      await db.put('test1', 1);

      var exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 0);
      expect(exportStat.lineCount, 2);
      expect(exportStat.obsoleteLineCount, 0);

      // put same
      await db.put('test1', 1);

      exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 0);
      expect(exportStat.lineCount, 3);
      expect(exportStat.obsoleteLineCount, 1);

      // delete
      await db.delete(1);

      exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 0);
      expect(exportStat.lineCount, 4);
      expect(exportStat.obsoleteLineCount, 2);
    });
  });

  group('compact', () {
    test('compact_and_write', () async {
      await prepareForDb();
      final db = await factory.openDatabase(dbPath) as SembastDatabase;
      await db.put('test1', 1);
      await db.compact();
      await db.put('test2', 2);
      await db.close();
      final lines = await readContent(fs, dbPath);
      expect(lines.length, 3);
      expect(json.decode(lines[1]), {'key': 1, 'value': 'test1'});
      expect(json.decode(lines[2]), {'key': 2, 'value': 'test2'});
    });

    test('compact_and_reopen', () async {
      await prepareForDb();
      final db = await factory.openDatabase(dbPath) as SembastDatabase;
      await db.put('test1', 1);
      await db.compact();
      await db.reOpen();
      await db.put('test2', 2);
      await db.close();
      final lines = await readContent(fs, dbPath);
      expect(lines.length, 3);
      expect(json.decode(lines[1]), {'key': 1, 'value': 'test1'});
      expect(json.decode(lines[2]), {'key': 2, 'value': 'test2'});
    });

    // tmp
    test('twice same record', () async {
      await prepareForDb();
      final db = await factory.openDatabase(dbPath) as SembastDatabase;
      await db.put('hi', 1);
      await db.put('hi', 1);
      await db.compact();
      await db.flush();
      var lines = await readContent(fs, dbPath);
      expect(lines.length, 2);
      expect(json.decode(lines[1]), {'key': 1, 'value': 'hi'});
      await db.close();
    });

    List<Record> generate(int count) {
      final records = <Record>[];
      for (var i = 1; i <= count; i++) {
        final record = Record(null, 'value$i', i);
        records.add(record);
      }
      return records;
    }

    test('auto_by_count', () async {
      await prepareForDb();
      final db = await factory.openDatabase(dbPath) as SembastDatabase;
      // write 6
      await db.putRecords(generate(6));
      // update 5
      await db.putRecords(generate(5));

      var exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 0);
      expect(exportStat.lineCount, 12);
      expect(exportStat.obsoleteLineCount, 5);

      // update 1 more to trigger auto compact
      await db.putRecords(generate(1));
      await db.flush();
      //await db.reOpen();

      exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 1);
      expect(exportStat.lineCount, 7);
      expect(exportStat.obsoleteLineCount, 0);
    });

    test('auto_by_count/delete', () async {
      await prepareForDb();
      final db = await factory.openDatabase(dbPath) as SembastDatabase;
      // write 6
      await db.putRecords(generate(6));
      // update 5
      await db.putRecords(generate(5));

      var exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 0);
      expect(exportStat.lineCount, 12);
      expect(exportStat.obsoleteLineCount, 5);

      // update 1 more to trigger auto compact
      await db.delete(1);
      await db.flush();

      exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 1);
      expect(exportStat.lineCount, 6); // as one has been deleted
      expect(exportStat.obsoleteLineCount, 0);
    });

    test('auto_by_count_reopon', () async {
      await prepareForDb();
      final db = await factory.openDatabase(dbPath) as SembastDatabase;
      await db.putRecords(generate(6));
      // devPrint(await readContent(fs, db.path));
      await db.putRecords(generate(6));

      await db.flush();
      // devPrint(await readContent(fs, db.path));

      final exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 1);
      expect(exportStat.lineCount, 7);
      expect(exportStat.obsoleteLineCount, 0);

      // devPrint(await readContent(fs, db.path));
      await db.reOpen();
      await db.flush();

      /*
      // devPrint(await readContent(fs, db.path));

      exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 0);
      expect(exportStat.lineCount, 7);
      expect(exportStat.obsoleteLineCount, 0);
       */
    });

    // tmp
    test('auto_by_ratio', () async {
      await prepareForDb();
      // 20% +
      final db = await factory.openDatabase(dbPath) as SembastDatabase;
      // write 30
      await db.putRecords(generate(30));
      // update 7 (that's 19.4% of 37
      await db.putRecords(generate(7));

      var exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 0);
      expect(exportStat.lineCount, 38);
      expect(exportStat.obsoleteLineCount, 7);

      // update 1 more to trigger auto compact
      await db.putRecords(generate(1));
      await db.flush();

      exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 1);
      expect(exportStat.lineCount, 31);
      expect(exportStat.obsoleteLineCount, 0);
    });
  });

  group('format_import', () {
    test('open_no_compact', () async {
      await prepareForDb();
      final line = json.encode({'key': 1, 'value': 2});
      // Compact is needed after 6 times the same record
      await writeContent(fs, dbPath, [
        json.encode({'version': 2, 'sembast': 1}),
        line,
        line,
        line,
        line,
        line,
        line
      ]);
      final db = await factory.openDatabase(dbPath) as SembastDatabase;
      expect(await db.get(1), 2);
      final lines = await readContent(fs, dbPath);
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
      await writeContent(fs, dbPath, [
        json.encode({'version': 2, 'sembast': 1}),
        line,
        line,
        line,
        line,
        line,
        line,
        line
      ]);
      final db = await factory.openDatabase(dbPath) as SembastDatabase;
      expect(await db.get(1), 2);
      final lines = await readContent(fs, dbPath);
      expect(lines.length, 2);

      //devPrintJson(db.toJson());
      final exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 1);
      expect(exportStat.lineCount, 2);
      expect(exportStat.obsoleteLineCount, 0);
    });
  });
}
