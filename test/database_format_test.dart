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
  });

  group("corrupted", () {
    test('corrupted', () async {
      await prepareForDb();
      await writeContent(fs, dbPath, ["corrupted"]);

      Future _deleteFile(String path) {
        return fs.newFile(path).delete();
      }

      Database db;
      try {
        db = await factory.openDatabase(dbPath);
      } on FormatException catch (_) {
        await _deleteFile(dbPath);
        db = await factory.openDatabase(dbPath);
      }
      expect(db.version, 1);
    });

    test('corrupted_open_empty', () async {
      await prepareForDb();
      await writeContent(fs, dbPath, ["corrupted"]);
      Database db = await factory.openDatabase(dbPath, mode: databaseModeEmpty);
      expect(db.version, 1);
    });
  });
}
