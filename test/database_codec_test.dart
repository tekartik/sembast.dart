library sembast.database_format_test;

import 'dart:async';
import 'dart:convert';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/file_system.dart';
import 'package:sembast/src/sembast_fs.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryFileSystemContext);
}

class MyJsonEncoder extends Converter<Map<String, dynamic>, String> {
  @override
  String convert(Map<String, dynamic> input) => json.encode(input);
}

class MyJsonDecoder extends Converter<String, Map<String, dynamic>> {
  @override
  Map<String, dynamic> convert(String input) {
    var result = json.decode(input);
    if (result is Map) {
      return result.cast<String, dynamic>();
    }
    throw FormatException('invalid input $input');
  }
}

class MyJsonCodec extends Codec<Map<String, dynamic>, String> {
  @override
  final decoder = MyJsonDecoder();
  @override
  final encoder = MyJsonEncoder();
}

void defineTests(FileSystemTestContext ctx) {
  FileSystem fs = ctx.fs;
  DatabaseFactory factory = DatabaseFactoryFs(fs);
  String getDbPath() => ctx.outPath + ".db";
  String dbPath;

  Future<String> prepareForDb() async {
    dbPath = getDbPath();
    await factory.deleteDatabase(dbPath);
    return dbPath;
  }

  group('basic code', () {
    setUp(() {
      //return fs.newFile(dbPath).delete().catchError((_) {});
    });

    var codec = SembastCodec(signature: 'json', codec: MyJsonCodec());
    tearDown(() {});

    test('open_no_version', () async {
      await prepareForDb();
      await factory.openDatabase(dbPath, codec: codec);
      List<String> lines = await readContent(fs, dbPath);
      expect(lines.length, 1);
      expect(json.decode(lines.first),
          {"version": 1, "sembast": 1, "codec": 'json'});
    });

    test('open_version_2', () async {
      await prepareForDb();
      await factory.openDatabase(dbPath, version: 2);
      List<String> lines = await readContent(fs, dbPath);
      expect(lines.length, 1);
      expect(json.decode(lines.first), {"version": 2, "sembast": 1});
    });

    test('1 string record', () async {
      await prepareForDb();
      return factory.openDatabase(dbPath).then((Database db) {
        return db.put("hi", 1);
      }).then((_) {
        return readContent(fs, dbPath).then((List<String> lines) {
          expect(lines.length, 2);
          expect(json.decode(lines[1]), {'key': 1, 'value': 'hi'});
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
          json.decode(lines[1]), {'store': 'store2', 'key': 1, 'value': 'hi'});
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
          expect(json.decode(lines[1]), {'key': 1, 'value': 'hi'});
          expect(json.decode(lines[2]), {'key': 1, 'value': 'hi'});
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
          expect(json.decode(lines[1]), {
            'key': 1,
            'value': {'test': 2}
          });
        });
      });
    });

    test('1_record_in_open', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath, version: 2,
          onVersionChanged: (db, _, __) async {
        await db.put('hi', 1);
      });
      try {
        List<String> lines = await readContent(fs, dbPath);
        expect(lines.length, 2);
        expect(json.decode(lines.first), {"version": 2, "sembast": 1});
        expect(json.decode(lines[1]), {'key': 1, 'value': 'hi'});
      } finally {
        await db?.close();
      }
    });

    test('1_record_in_open_transaction', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath, version: 2,
          onVersionChanged: (db, _, __) async {
        await db.transaction((txn) async {
          await txn.put('hi', 1);
        });
      });
      try {
        List<String> lines = await readContent(fs, dbPath);
        expect(lines.length, 2);
        expect(json.decode(lines.first), {"version": 2, "sembast": 1});
        expect(json.decode(lines[1]), {'key': 1, 'value': 'hi'});
      } finally {
        await db?.close();
      }
    });
  });

  group('format_import', () {
    test('open_version_2', () async {
      await prepareForDb();
      await writeContent(fs, dbPath, [
        json.encode({"version": 2, "sembast": 1})
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
        return fs.file(path).delete();
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
      Database db =
          await factory.openDatabase(dbPath, mode: DatabaseMode.empty);
      expect(db.version, 1);
    });
  });
}