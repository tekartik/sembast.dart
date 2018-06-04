library sembast.transaction_test;

// basically same as the io runner but with extra output
import 'dart:async';

import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/transaction_impl.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('currentTransaction', () {
    SembastDatabase db;

    setUp(() async {
      db = await setupForTest(ctx) as SembastDatabase;
    });

    tearDown(() {
      db.close();
    });

    test('put/get', () {
      List<Future> futures = [];
      expect(db.currentTransaction, isNull);
      futures.add(db.put("hi", 1));
      // expect(db.currentTransaction, isNull);
      // here the value should not be loaded yet
      futures.add(db.get(1).then((value) {
        //expect(db.currentTransaction, isNull);
        expect(value, null);
      }));
      return Future.wait(futures);
    });

    test('put then get', () {
      return db.put("hi", 1).then((_) {
        // expect(db.currentTransaction, isNull);
        // here the value should not be loaded yet
        return db.get(1).then((value) {
          // expect(db.currentTransaction, isNull);
        });
      });
    });

    test('put/clear/get in currentTransaction', () async {
      SembastTransaction txn;
      await db.inTransaction(() {
        txn = db.currentTransaction;
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

    test('one currentTransaction', () {
      db.inTransaction(() {
        expect(db.currentTransaction.id, 1);
        return new Future.value().then((_) {
          expect(db.currentTransaction.id, 1);
        }).then((_) {
          expect(db.currentTransaction.id, 1);
        });
      }).then((_) {
        expect(db.currentTransaction, null);
      });
    });

    test('inner currentTransaction', () {
      db.inTransaction(() {
        expect(db.currentTransaction.id, 1);
        return db.inTransaction(() {
          expect(db.currentTransaction.id, 1);
        }).then((_) {
          expect(db.currentTransaction.id, 1);
        });
      }).then((_) {
        expect(db.currentTransaction, null);
      });
    });

    test('inner new currentTransaction', () {
      db.inTransaction(() {
        expect(db.currentTransaction.id, 1);
        new Future.value().then((_) {
          expect(db.currentTransaction.id, 1);
        }).then((_) {
          expect(db.currentTransaction.id, 1);
        });
      }).then((_) {
        expect(db.currentTransaction, null);
      });
    });

    test('two currentTransaction', () {
      db.inTransaction(() {
        expect(db.currentTransaction.id, 1);
      }).then((_) {
        // expect(db.currentTransaction, null);
      });
      return db.inTransaction(() {
        expect(db.currentTransaction.id, 2);
      }).then((_) {
        // expect(db.currentTransaction, null);
      });
    });

    test('two currentTransaction follow', () {
      db.inTransaction(() {
        expect(db.currentTransaction.id, 1);
      }).then((_) {
        expect(db.currentTransaction, null);
        return db.inTransaction(() {
          expect(db.currentTransaction.id, 2);
        }).then((_) {
          expect(db.currentTransaction, null);
        });
      });
    });
  });
}
