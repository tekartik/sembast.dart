library sembast.database_format_test;

// basically same as the io runner but with extra output
import 'package:test/test.dart';
import 'package:sembast/src/memory/memory_file_system.dart';
import 'package:sembast/src/file_system.dart';
import 'package:sembast/src/sembast_fs.dart';
import 'package:sembast/sembast.dart';
import 'test_common.dart';
import 'dart:convert';

void main() {
  defineTests(memoryFileSystem);
}

void defineTests(FileSystem fs) {
  DatabaseFactory factory = new FsDatabaseFactory(fs);
  String dbPath = testOutDbPath(fs);

  group('basic format', () {
    setUp(() {
      return fs.newFile(dbPath).delete().catchError((_) {});
    });

    tearDown(() {});

    test('open_no_version', () {
      return factory.openDatabase(dbPath).then((Database db) {
        return readContent(fs, dbPath).then((List<String> lines) {
          expect(lines.length, 1);
          expect(JSON.decode(lines.first), {"version": 1, "sembast": 1});
        });
      });
    });

    test('1 string record', () {
      return factory.openDatabase(dbPath).then((Database db) {
        return db.put("hi", 1);
      }).then((_) {
        return readContent(fs, dbPath).then((List<String> lines) {
          expect(lines.length, 2);
          expect(JSON.decode(lines[1]), {'key': 1, 'value': 'hi'});
        });
      });
    });

    test('twice same record', () {
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

    test('1 map record', () {
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

    // tmp
    test('compact twice same record', () {
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

    test('auto auto compact by count', () {
      return factory.openDatabase(dbPath).then((Database db) {
        // write 6
        return db.putRecords(generate(6)).then((_) {
          // update 5
          return db.putRecords(generate(5)).then((_) {});
        }).then((_) {
          return db.reOpen().then((_) {
            return readContent(fs, dbPath).then((List<String> lines) {
              expect(lines.length, 12);
            });
          });
        }).then((_) {
          // update 1 more to trigger auto compact
          return db.putRecords(generate(1)).then((_) {});
        }).then((_) {
          return db.reOpen().then((_) {
            return readContent(fs, dbPath).then((List<String> lines) {
              expect(lines.length, 7);
            });
          });
        });
      });
    });

    // tmp
    test('auto auto compact by ratio', () {
      // 20% +
      return factory.openDatabase(dbPath).then((Database db) {
        // write 30
        return db.putRecords(generate(30)).then((_) {
          // update 7 (that's 19.4% of 37
          return db.putRecords(generate(7)).then((_) {});
        }).then((_) {
          return db.reOpen().then((_) {
            return readContent(fs, dbPath).then((List<String> lines) {
              expect(lines.length, 38);
            });
          });
        }).then((_) {
          // update 1 more to trigger auto compact
          return db.putRecords(generate(1)).then((_) {});
        }).then((_) {
          return db.reOpen().then((_) {
            return readContent(fs, dbPath).then((List<String> lines) {
              expect(lines.length, 31);
            });
          });
        });
      });
    });
  });

  group('format_import', () {
    setUp(() {
      return fs.newFile(dbPath).delete().catchError((_) {});
    });

    tearDown(() {});

    test('open_version_2', () async {
      await writeContent(fs, dbPath, [
        JSON.encode({"version": 2, "sembast": 1})
      ]);
      return factory.openDatabase(dbPath).then((Database db) {
        expect(db.version, 2);
      });
    });

    test('open_no_compact', () async {
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
    });

    test('open_compact', () async {
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
    });
  });
}
