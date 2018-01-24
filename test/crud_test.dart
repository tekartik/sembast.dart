library sembast.crud_test;

// basically same as the io runner but with extra output
import 'package:sembast/sembast.dart';
import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('crud', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx);
    });

    tearDown(() {
      db.close();
    });

    test('put', () {
      return db.put("hi", 1).then((key) {
        expect(key, 1);
      });
    });

    test('put_nokey', () {
      return db.put("hi").then((key) {
        expect(key, 1);
        return db.put("hi").then((key) {
          expect(key, 2);
        });
      });
    });

    test('get none', () {
      return db.get(1).then((value) {
        expect(value, isNull);
      });
    });

    test('put_get', () {
      String value = "hi";
      return db.put(value, 1).then((_) {
        return db.get(1).then((readValue) {
          expect(readValue, "hi");
          // immutable value are not clones
          expect(identical(value, readValue), isTrue);
          return db.count().then((int count) {
            expect(count, 1);
          });
        });
      });
    });

    test('put_update', () {
      return db.put("hi", 1).then((_) {
        return db.put("ho", 1).then((_) {
          return db.get(1).then((value) {
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
          return db.get(1).then((value) {
            expect(value, "hi");
          });
        });
      });
    });

    test('put_nokey_close_put', () {
      return db.put("hi").then((key) {
        return db.reOpen().then((_) {
          return db.put("hi").then((key) {
            expect(key, 2);
          });
        });
      });
    });

    test('put_update_close_get', () {
      return db.put("hi", 1).then((_) {
        return db.put("ho", 1).then((_) {
          return db.reOpen().then((_) {
            return db.get(1).then((value) {
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
          return db.get("1").then((value) {
            expect(value, "hi");
          });
        });
      });
    });

    test('put_close_get_map', () {
      Map info = {"info": 12};
      return db.put(info, 1).then((_) {
        return db.reOpen().then((_) {
          return db.get(1).then((infoRead) {
            expect(infoRead, info);
            expect(identical(infoRead, info), isFalse);
          });
        });
      });
    });

    test('auto_increment put_get_map', () {
      Map info = {"info": 12};
      return db.put(info).then((key) {
        return db.get(key).then((infoRead) {
          expect(infoRead, info);
          expect(identical(infoRead, info), isFalse);
        });
      });
    });
  });
}
