library tekartik_iodb.teansaction_test;

// basically same as the io runner but with extra output
import 'package:tekartik_test/test_config_io.dart';
import 'package:sembast/database.dart';
import 'package:tekartik_io_tools/platform_utils.dart';
import 'package:path/path.dart';
import 'dart:async';
import 'package:sembast/database_memory.dart';
import 'database_test.dart';

void main() {
  useVMConfiguration();
  defineTests(memoryDatabaseFactory);
}

void defineTests(DatabaseFactory factory) {

  group('transaction', () {

    String dbPath = join(scriptDirPath, "tmp", "test.db");
    Database db;

    setUp(() {
      return setupForTest(factory).then((Database database) {
        db = database;
      });
    });

    tearDown(() {
      db.close();
    });

    test('put/get', () {
      List<Future> futures = [];
      futures.add(db.put("hi", 1));
      // here the value should not be loaded yet
      futures.add(db.get(1).then((String value) {
        expect(value, null);

      }));
      return Future.wait(futures);
    });

    test('put in transaction', () {
      List<Future> futures = [];
      futures.add(db.inTransaction(() {
        return db.put("hi", 1).then((_) {
          return db.get(1).then((String value) {
            expect(value, "hi");
          });
        });
      }));

      // here we are in a transaction so it will wait for the other to finish
      futures.add(db.inTransaction(() {
        return db.get(1).then((String value) {
          expect(value, "hi");
        });
      }));

      // here the value should not be loaded yet
      futures.add(db.get(1).then((String value) {
        expect(value, null);

      }));
      return Future.wait(futures);
    });

    test('put and rollback', () {
      return db.inTransaction(() {
        return db.put("hi", 1).then((_) {
          // still here
          return db.get(1).then((String value) {
            expect(value, "hi");
          }).then((_) {
            db.rollback();
            return db.get(1).then((String value) {
              expect(value, null);
            });
          });
        });
      }).then((_) {
        // put something else to make sure the txn has been cleaned
        return db.put("ho", 2).then((_) {
          return db.get(1).then((String value) {
            expect(value, null);
          });
        });
      });
    });

    test('delete and rollback', () {
      return db.put("hi", 1).then((_) {
        return db.inTransaction(() {
          return db.delete(1).then((_) {
            // still here
            return db.get(1).then((String value) {
              expect(value, null);
            }).then((_) {
              db.rollback();
              return db.get(1).then((String value) {
                expect(value, "hi");
              });
            });
          });
        }).then((_) {
          // put something else to make sure the txn has been cleaned
          return db.put("ho", 2).then((_) {
            return db.get(1).then((String value) {
              expect(value, "hi");
            });
          });
        });
      });
    });

    test('put and throw', () {
      return db.inTransaction(() {
        return db.put("hi", 1).then((_) {
          // still here
          return db.get(1).then((String value) {
            expect(value, "hi");
          }).then((_) {
            throw "some failure";
          });
        });
      }).catchError((String err) {
        expect(err, "some failure");
      }).then((_) {
        // put something else to make sure the txn has been cleaned
        return db.put("ho", 2).then((_) {
          return db.get(1).then((String value) {
            expect(value, null);
          });
        });
      });
    });


  });
}
