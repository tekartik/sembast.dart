library sembast.transaction_test;

// basically same as the io runner but with extra output
import 'package:sembast/sembast.dart';
import 'dart:async';
import 'package:sembast/src/database.dart';
import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('transaction', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx);
    });

    tearDown(() {
      db.close();
    });

    test('put/get', () async {
      List<Future> futures = [];
      futures.add(db.put("hi", 1));
      futures.add(db.get(1).then((value) {
        expect(value, null);
      }));
      await Future.wait(futures);
      expect(await db.get(1), "hi");
    });

    test('put/clear/get in transaction', () async {
      await db.inTransaction(() {
        return db.put("hi", 1).then((_) {
          return db.mainStore.clear().then((_) {
            return db.get(1).then((value) {
              expect(value, null);
            });
          });
        });
      });
    });

    test('put in transaction', () {
      List<Future> futures = [];
      futures.add(db.inTransaction(() {
        return db.put("hi", 1).then((_) {
          return db.get(1).then((value) {
            expect(value, "hi");
          });
        });
      }));

      // here we are in a transaction so it will wait for the other to finish
      futures.add(db.inTransaction(() {
        return db.get(1).then((value) {
          expect(value, "hi");
        });
      }));

      // here the value should not be loaded yet
      futures.add(db.get(1).then((value) {
        expect(value, null);
      }));
      return Future.wait(futures);
    });

    test('put in sub transaction', () {
      return db.inTransaction(() {
        return db.inTransaction(() {
          return db.put("hi", 1).then((_) {
            return db.get(1).then((value) {
              expect(value, "hi");
            });
          });
        });
      });
    });

    test('put in sub sub transaction', () {
      return db.inTransaction(() {
        return db.inTransaction(() {
          return db.inTransaction(() {
            return db.put("hi", 1).then((_) {
              return db.get(1).then((value) {
                expect(value, "hi");
              });
            });
          });
        });
      });
    });

    test('put and throw', () {
      return db.inTransaction(() {
        return db.put("hi", 1).then((_) {
          // still here
          return db.get(1).then((value) {
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
          return db.get(1).then((value) {
            expect(value, null);
          });
        });
      });
    });

    // timing is changing for dart2...
    test('transaction timing', () async {
      //sembastUseSynchronized = false;

      _do() async {
        StringBuffer sb = new StringBuffer();
        new Future(() {
          sb.write('1');
        });

        await db.inTransaction(() async {
          // first action is delayed
          sb.write('2');

          var future = new Future(() {
            sb.write('4');
          });
          // not the second one
          await db.inTransaction(() async {
            sb.write('3');
          });
          await future;
        });

        //print(sb);
        expect(sb.toString(), "1234");
      }

      //sembastUseSynchronized = false;
      //await _do();
      //sembastUseSynchronized = true;
      await _do();
    }, skip: true);
  });
}
