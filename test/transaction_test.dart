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
    SembastDatabase db;

    setUp(() async {
      db = await setupForTest(ctx) as SembastDatabase;
    });

    tearDown(() {
      db.close();
    });

    test('put/get', () {
      List<Future> futures = [];
      expect(db.transaction, isNull);
      futures.add(db.put("hi", 1));
      expect(db.transaction, isNull);
      // here the value should not be loaded yet
      futures.add(db.get(1).then((value) {
        expect(db.transaction, isNull);
        expect(value, null);
      }));
      return Future.wait(futures);
    });

    test('put then get', () {
      return db.put("hi", 1).then((_) {
        expect(db.transaction, isNull);
        // here the value should not be loaded yet
        return db.get(1).then((value) {
          expect(db.transaction, isNull);
        });
      });
    });

    test('put/clear/get in transaction', () async {
      Transaction txn;
      await db.inTransaction(() {
        txn = db.transaction;
        return db.put("hi", 1).then((_) {
          return db.mainStore.clear().then((_) {
            return db.get(1).then((value) {
              expect(value, null);
              expect(txn.isCompleted, isFalse);
            });
          });
        });
      });
      expect(txn.isCompleted, isTrue);
      await txn.completed;
      expect(txn.isCompleted, isTrue);
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

    test('put and rollback', () {
      return db.inTransaction(() {
        return db.put("hi", 1).then((_) {
          // still here
          return db.get(1).then((value) {
            expect(value, "hi");
          }).then((_) {
            db.rollback();
            return db.get(1).then((value) {
              expect(value, null);
            });
          });
        });
      }).then((_) {
        // put something else to make sure the txn has been cleaned
        return db.put("ho", 2).then((_) {
          return db.get(1).then((value) {
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
            return db.get(1).then((value) {
              expect(value, null);
            }).then((_) {
              db.rollback();
              return db.get(1).then((value) {
                expect(value, "hi");
              });
            });
          });
        }).then((_) {
          // put something else to make sure the txn has been cleaned
          return db.put("ho", 2).then((_) {
            return db.get(1).then((value) {
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

    test('one transaction', () {
      db.inTransaction(() {
        expect(db.transaction.id, 1);
        return new Future.value().then((_) {
          expect(db.transaction.id, 1);
        }).then((_) {
          expect(db.transaction.id, 1);
        });
      }).then((_) {
        expect(db.transaction, null);
      });
    });

    test('inner transaction', () {
      db.inTransaction(() {
        expect(db.transaction.id, 1);
        return db.inTransaction(() {
          expect(db.transaction.id, 1);
        }).then((_) {
          expect(db.transaction.id, 1);
        });
      }).then((_) {
        expect(db.transaction, null);
      });
    });

    test('inner new transaction', () {
      db.inTransaction(() {
        expect(db.transaction.id, 1);
        new Future.value().then((_) {
          expect(db.transaction.id, 1);
        }).then((_) {
          expect(db.transaction.id, 1);
        });
      }).then((_) {
        expect(db.transaction, null);
      });
    });

    test('two transaction', () {
      db.inTransaction(() {
        expect(db.transaction.id, 1);
      }).then((_) {
        expect(db.transaction, null);
      });
      return db.inTransaction(() {
        expect(db.transaction.id, 2);
      }).then((_) {
        expect(db.transaction, null);
      });
    });

    test('two transaction follow', () {
      db.inTransaction(() {
        expect(db.transaction.id, 1);
      }).then((_) {
        expect(db.transaction, null);
        return db.inTransaction(() {
          expect(db.transaction.id, 2);
        }).then((_) {
          expect(db.transaction, null);
        });
      });
    });

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
    });
  });
}
