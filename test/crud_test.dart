library tekartik_iodb.crud_test;

// basically same as the io runner but with extra output
import 'package:tekartik_test/test_config_io.dart';
import 'package:tekartik_iodb/database.dart';
import 'package:tekartik_io_tools/platform_utils.dart';
import 'package:path/path.dart';


void main() {
  useVMConfiguration();
  defineTests();
}

void defineTests() {


  String dbPath = join(scriptDirPath, "tmp", "test.db");

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

    test('put_nokey', () {
      return db.put("hi").then((int key) {
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

    test('put_nokey_close_put', () {
      return db.put("hi").then((int key) {
        return db.reOpen().then((_) {
          return db.put("hi").then((int key) {
            expect(key, 2);
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
}
