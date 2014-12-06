library test_utils_test;

// basically same as the io runner but with extra output
import 'package:tekartik_test/test_config_io.dart';
import 'package:tekartik_iodb/database.dart';
import 'package:tekartik_io_tools/file_utils.dart';
import 'package:tekartik_io_tools/platform_utils.dart';
import 'package:path/path.dart';



main() {
  useVMConfiguration();
  group('database', () {

    String dbPath = join(scriptDirPath, "tmp", "test.db");
    group('open', () {
      Database db;

      setUp(() {
        db = new Database();
        return Database.deleteDatabase(dbPath);
      });

      tearDown(() {
        db.close();
      });

      test('open_no_version', () {
        return db.open(dbPath).then((_) {
          fail("should fail");
        }).catchError((_) {
          // opk
        });
      });

      test('open', () {
        return db.open(dbPath, 1).then((_) {
          expect(db.path, dbPath);
          expect(db.version, 1);
        });
      });

      test('open_then_open_no_version', () {
        return db.open(dbPath, 1).then((_) {
          db.close();
          return db.open(dbPath).then((_) {
            expect(db.path, dbPath);
            expect(db.version, 1);
          });
        });
      });

    });

    group('crud', () {
      Database db;

      setUp(() {
        db = new Database();
        return Database.deleteDatabase(dbPath).then((_) {
          return db.open(dbPath, 1);
        });
      });

      tearDown(() {
        db.close();
      });

      test('put', () {
        return db.put("hi", 1).then((int key) {
          expect(key, 1);
        });
      });

      test('get none', () {
        return db.get(1).then((value) {
          expect(value, isNull);
        });
      });

      test('put_get', () {
        return db.put("hi", 1).then((_) {
          return db.get(1).then((String value) {
            expect(value, "hi");
            return db.count().then((int count) {
              expect(count, 1);
            });
          });
        });
      });

      test('put_update', () {
        return db.put("hi", 1).then((_) {
          return db.put("ho", 1).then((_) {
            return db.get(1).then((String value) {
              expect(value, "ho");
              return db.count().then((int count) {
                expect(count, 1);
              });
            });
          });
        });
      });

      test('put_delete', () {
        return db.put("hi", 1).then((_) {
          return db.delete(1).then((key) {
            expect(key, 1);
            return db.get(1).then((value) {
              expect(value, isNull);
              return db.count().then((int count) {
                expect(count, 0);
              });
            });
          });
        });
      });

      test('put_close_get', () {
        return db.put("hi", 1).then((_) {
          return db.reOpen().then((_) {
            return db.get(1).then((String value) {
              expect(value, "hi");

            });
          });
        });
      });

      test('put_update_close_get', () {
        return db.put("hi", 1).then((_) {
          return db.put("ho", 1).then((_) {
            return db.reOpen().then((_) {
              return db.get(1).then((String value) {
                expect(value, "ho");
                return db.count().then((int count) {
                  expect(count, 1);
                });
              });
            });
          });
        });
      });
      
      test('put_delete_close_get', () {
        return db.put("hi", 1).then((_) {
          return db.delete(1).then((key) {
            return db.reOpen().then((_) {
              return db.get(1).then((value) {
                expect(value, isNull);
                return db.count().then((int count) {
                  expect(count, 0);
                });
              });
            });
          });
        });
      });

      test('put_close_get_key_string', () {
        return db.put("hi", "1").then((_) {
          return db.reOpen().then((_) {
            return db.get("1").then((String value) {
              expect(value, "hi");
            });
          });
        });
      });

      test('put_close_get_map', () {
        Map info = {
          "info": 12
        };
        return db.put(info, 1).then((_) {
          return db.reOpen().then((_) {
            return db.get(1).then((Map infoRead) {
              expect(infoRead, info);
            });
          });
        });
      });


    });

  });
}
