library sembast.database_format_test;

import 'package:sembast/src/file_system.dart';
import 'package:sembast/src/sembast_fs.dart';
import 'package:sembast/sembast.dart';
import 'test_common.dart';
import 'dart:convert';
import 'dart:async';

void main() {
  defineTests(memoryFileSystemContext);
}

void defineTests(FileSystemTestContext ctx) {
  FileSystem fs = ctx.fs;
  DatabaseFactory factory = new FsDatabaseFactory(fs);
  String getDbPath() => ctx.outPath + ".db";
  String dbPath;

  Future<String> prepareForDb() async {
    dbPath = getDbPath();
    await fs.newFile(dbPath).delete().catchError((_) {});
    return dbPath;
  }
  group('basic format', () {
    setUp(() {
      //return fs.newFile(dbPath).delete().catchError((_) {});
    });

    tearDown(() {});

    test('open_no_version', () async {
      await prepareForDb();
      await factory.openDatabase(dbPath);
      List<String> lines = await readContent(fs, dbPath);
      expect(lines.length, 1);
      expect(JSON.decode(lines.first), {"version": 1, "sembast": 1});
    });

    test('open_version_2', () async {
      await prepareForDb();
      await factory.openDatabase(dbPath, version: 2);
      List<String> lines = await readContent(fs, dbPath);
      expect(lines.length, 1);
      expect(JSON.decode(lines.first), {"version": 2, "sembast": 1});
    });

    test('1 string record', () async {
      await prepareForDb();
      return factory.openDatabase(dbPath).then((Database db) {
        return db.put("hi", 1);
      }).then((_) {
        return readContent(fs, dbPath).then((List<String> lines) {
          expect(lines.length, 2);
          expect(JSON.decode(lines[1]), {'key': 1, 'value': 'hi'});
        });
      });
    });

    test('1_record_in_2_stores', () async {
      await prepareForDb();
      Database db = await factory.openDatabase(dbPath);
      db.getStore('store1');
      Store store2 = db.getStore('store2');
      await store2.put("hi", 1);
      List<String> lines = await readContent(fs, dbPath);
      expect(lines.length, 2);
      expect(
          JSON.decode(lines[1]), {'store': 'store2', 'key': 1, 'value': 'hi'});
    });

    test('twice same record', () async {
      await prepareForDb();
      return factory.openDatabase(dbPath).then((Database db) {
        return db.put("hi", 1).then((_) {
          return db.put("hi", 1);
        });
      }).then((_) {
        return readContent(fs, dbPath).then((List<String> lines) {
          expect(lines.length, 3);
          expect(JSON.decode(lines[1]), {'key': 1, 'value': 'hi'});
          expect(JSON.decode(lines[2]), {'key': 1, 'value': 'hi'});
        });
      });
    });

    test('1 map record', () async {
      await prepareForDb();
      return factory.openDatabase(dbPath).then((Database db) {
        return db.put({'test': 2}, 1);
      }).then((_) {
        return readContent(fs, dbPath).then((List<String> lines) {
          expect(lines.length, 2);
          expect(JSON.decode(lines[1]), {
            'key': 1,
            'value': {'test': 2}
          });
        });
      });
    });
  });

  group('exportStat', () {
    setUp(() async {
      await prepareForDb();
    });

    test('add/put/delete', () async {
      Database db = await factory.openDatabase(dbPath);
      await db.put("test1", 1);

      DatabaseExportStat exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 0);
      expect(exportStat.lineCount, 2);
      expect(exportStat.obsoleteLineCount, 0);

      // put same
      await db.put("test1", 1);

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
      Database db = await factory.openDatabase(dbPath);
      await db.put("test1", 1);
      await db.compact();
      await db.put("test2", 2);
      List<String> lines = await readContent(fs, dbPath);
      expect(lines.length, 3);
      expect(JSON.decode(lines[1]), {'key': 1, 'value': 'test1'});
      expect(JSON.decode(lines[2]), {'key': 2, 'value': 'test2'});
    });

    test('compact_and_reopen', () async {
      await prepareForDb();
      Database db = await factory.openDatabase(dbPath);
      await db.put("test1", 1);
      await db.compact();
      await db.reOpen();
      await db.put("test2", 2);
      List<String> lines = await readContent(fs, dbPath);
      expect(lines.length, 3);
      expect(JSON.decode(lines[1]), {'key': 1, 'value': 'test1'});
      expect(JSON.decode(lines[2]), {'key': 2, 'value': 'test2'});
    });

    // tmp
    test('twice same record', () async {
      await prepareForDb();
      return factory.openDatabase(dbPath).then((Database db) {
        return db.put("hi", 1).then((_) {
          return db.put("hi", 1);
        }).then((_) {
          return db.compact();
        });
      }).then((_) {
        return readContent(fs, dbPath).then((List<String> lines) {
          expect(lines.length, 2);
          expect(JSON.decode(lines[1]), {'key': 1, 'value': 'hi'});
        });
      });
    });

    List<Record> generate(int count) {
      List<Record> records = [];
      for (int i = 1; i <= count; i++) {
        Record record = new Record(null, "value$i", i);
        records.add(record);
      }
      return records;
    }

    test('auto_by_count', () async {
      await prepareForDb();
      Database db = await factory.openDatabase(dbPath);
      // write 6
      await db.putRecords(generate(6));
      // update 5
      await db.putRecords(generate(5));

      DatabaseExportStat exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 0);
      expect(exportStat.lineCount, 12);
      expect(exportStat.obsoleteLineCount, 5);

      // update 1 more to trigger auto compact
      await db.putRecords(generate(1));

      //await db.reOpen();

      exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 1);
      expect(exportStat.lineCount, 7);
      expect(exportStat.obsoleteLineCount, 0);
    });

    test('auto_by_count/delete', () async {
      await prepareForDb();
      Database db = await factory.openDatabase(dbPath);
      // write 6
      await db.putRecords(generate(6));
      // update 5
      await db.putRecords(generate(5));

      DatabaseExportStat exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 0);
      expect(exportStat.lineCount, 12);
      expect(exportStat.obsoleteLineCount, 5);

      // update 1 more to trigger auto compact
      await db.delete(1);

      //await db.reOpen();

      exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 1);
      expect(exportStat.lineCount, 6); // as one has been deleted
      expect(exportStat.obsoleteLineCount, 0);
    });

    test('auto_by_count/reopon', () async {
      await prepareForDb();
      Database db = await factory.openDatabase(dbPath);
      await db.putRecords(generate(6));
      await db.putRecords(generate(6));

      DatabaseExportStat exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 1);
      expect(exportStat.lineCount, 7);
      expect(exportStat.obsoleteLineCount, 0);

      await db.reOpen();

      exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 0);
      expect(exportStat.lineCount, 7);
      expect(exportStat.obsoleteLineCount, 0);
    });

    // tmp
    test('auto_by_ratio', () async {
      await prepareForDb();
      // 20% +
      Database db = await factory.openDatabase(dbPath);
      // write 30
      await db.putRecords(generate(30));
      // update 7 (that's 19.4% of 37
      await db.putRecords(generate(7));

      DatabaseExportStat exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 0);
      expect(exportStat.lineCount, 38);
      expect(exportStat.obsoleteLineCount, 7);

      // update 1 more to trigger auto compact
      await db.putRecords(generate(1));

      exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 1);
      expect(exportStat.lineCount, 31);
      expect(exportStat.obsoleteLineCount, 0);
    });
  });

  group('format_import', () {
    test('open_version_2', () async {
      await prepareForDb();
      await writeContent(fs, dbPath, [
        JSON.encode({"version": 2, "sembast": 1})
      ]);
      return factory.openDatabase(dbPath).then((Database db) {
        expect(db.version, 2);
      });
    });

    test('open_no_compact', () async {
      await prepareForDb();
      String line = JSON.encode({"key": 1, "value": 2});
      // Compact is needed after 6 times the same record
      await writeContent(fs, dbPath, [
        JSON.encode({"version": 2, "sembast": 1}),
        line,
        line,
        line,
        line,
        line,
        line
      ]);
      Database db = await factory.openDatabase(dbPath);
      expect(await db.get(1), 2);
      List<String> lines = await readContent(fs, dbPath);
      expect(lines.length, 7);

      DatabaseExportStat exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 0);
      expect(exportStat.lineCount, 7);
      expect(exportStat.obsoleteLineCount, 5);
    });

    test('open_compact', () async {
      await prepareForDb();
      String line = JSON.encode({"key": 1, "value": 2});
      // Compact is needed after 6 times the same record
      await writeContent(fs, dbPath, [
        JSON.encode({"version": 2, "sembast": 1}),
        line,
        line,
        line,
        line,
        line,
        line,
        line
      ]);
      Database db = await factory.openDatabase(dbPath);
      expect(await db.get(1), 2);
      List<String> lines = await readContent(fs, dbPath);
      expect(lines.length, 2);

      //devPrintJson(db.toJson());
      DatabaseExportStat exportStat = getDatabaseExportStat(db);
      expect(exportStat.compactCount, 1);
      expect(exportStat.lineCount, 2);
      expect(exportStat.obsoleteLineCount, 0);
    });
  });
}
