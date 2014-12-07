library tekartik_iodb.teansaction_test;

// basically same as the io runner but with extra output
import 'package:tekartik_test/test_config_io.dart';
import 'package:tekartik_iodb/database.dart';
import 'package:tekartik_io_tools/platform_utils.dart';
import 'package:path/path.dart';
import 'dart:async';

void main() {
  useVMConfiguration();
  defineTests();
}

void defineTests() {
  group('transaction', () {

    String dbPath = join(scriptDirPath, "tmp", "test.db");
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
