library sembast.database_format_test;

// basically same as the io runner but with extra output
import 'package:tekartik_test/test_config_io.dart';
import 'package:sembast/src/memory/memory_file_system.dart';
import 'package:sembast/src/io/io_file_system.dart';
import 'package:sembast/src/file_system.dart';
import 'package:sembast/src/sembast_fs.dart';
import 'package:sembast/sembast.dart';
import 'test_common.dart';
import 'dart:convert';

void main() {
  useVMConfiguration();
  defineTests(ioFileSystem);
}

void defineTests(FileSystem fs) {

  DatabaseFactory factory = new FsDatabaseFactory(fs);
  String dbPath = testOutDbPath(fs);

  group('basic format', () {

    setUp(() {
      return fs.newFile(dbPath).delete().catchError((_) {

      });
    });

    tearDown(() {
    });

    test('open_no_version', () {
      return factory.openDatabase(dbPath).then((Database db) {
        return readContent(fs, dbPath).then((List<String> lines) {
          expect(lines.length, 1);
          expect(JSON.decode(lines.first), {
            "version": 1,
            "sembast": 1
          });
        });
      });
    });

    test('1 string record', () {
      return factory.openDatabase(dbPath).then((Database db) {
        return db.put("hi", 1);
      }).then((_) {
        return readContent(fs, dbPath).then((List<String> lines) {
          expect(lines.length, 2);
          expect(JSON.decode(lines[1]), {
            'key': 1,
            'value': 'hi'
          });
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
          expect(JSON.decode(lines[1]), {
            'key': 1,
            'value': 'hi'
          });
          expect(JSON.decode(lines[2]), {
            'key': 1,
            'value': 'hi'
          });
        });
      });
    });

    test('1 map record', () {
      return factory.openDatabase(dbPath).then((Database db) {
        return db.put({
          'test': 2
        }, 1);
      }).then((_) {
        return readContent(fs, dbPath).then((List<String> lines) {
          expect(lines.length, 2);
          expect(JSON.decode(lines[1]), {
            'key': 1,
            'value': {
              'test': 2
            }
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
          expect(JSON.decode(lines[1]), {
            'key': 1,
            'value': 'hi'
          });

        });
      });
    });
  });

}
