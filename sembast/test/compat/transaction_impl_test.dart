library sembast.transaction_test;

// ignore_for_file: deprecated_member_use_from_same_package

// basically same as the io runner but with extra output
import 'dart:async';

import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/transaction_impl.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('transaction_impl', () {
    SembastDatabase db;

    setUp(() async {
      db = await setupForTest(ctx, 'compat/transaction_impl.db')
          as SembastDatabase;
    });

    tearDown(() {
      return db.close();
    });

    test('put/get', () {
      final futures = <Future>[];
      expect(db.currentTransaction, isNull);
      futures.add(db.put('hi', 1));
      // expect(db.currentTransaction, isNull);
      // here the value should not be loaded yet
      futures.add(db.get(1).then((value) {
        //expect(db.currentTransaction, isNull);
        expect(value, null);
      }));
      return Future.wait(futures);
    });

    test('put then get', () {
      return db.put('hi', 1).then((_) {
        // expect(db.currentTransaction, isNull);
        // here the value should not be loaded yet
        return db.get(1).then((value) {
          // expect(db.currentTransaction, isNull);
        });
      });
    });

    test('put/clear/get in currentTransaction', () async {
      SembastTransaction sembastTransaction;
      await db.transaction((txn) {
        sembastTransaction = txn as SembastTransaction;
        expect(sembastTransaction.isCompleted, isFalse);
        return txn.put('hi', 1).then((_) {
          return txn.mainStore.clear().then((_) {
            return txn.get(1).then((value) {
              expect(value, null);
            });
          });
        });
      });
      expect(sembastTransaction.isCompleted, isTrue);
      await sembastTransaction.completed;
      expect(sembastTransaction.isCompleted, isTrue);
    });

    test('put and rollback', () async {
      await db.transaction((txn) {
        return txn.put('hi', 1).then((_) {
          // still here
          return txn.get(1).then((value) {
            expect(value, 'hi');
          }).then((_) {
            db.txnRollback(txn as SembastTransaction);
            return txn.get(1).then((value) {
              expect(value, null);
            });
          });
        });
      });
      expect(await db.get(1), isNull);
      // put something else to make sure the txn has been cleaned
      return db.put('ho', 2).then((_) {
        return db.get(1).then((value) {
          expect(value, null);
        });
      });
    });

    test('delete and rollback', () {
      return db.put('hi', 1).then((_) {
        return db.transaction((txn) {
          return txn.delete(1).then((_) {
            // still here
            return txn.get(1).then((value) {
              expect(value, null);
            }).then((_) {
              db.txnRollback(txn as SembastTransaction);
              return txn.get(1).then((value) {
                expect(value, 'hi');
              });
            });
          });
        }).then((_) {
          // put something else to make sure the txn has been cleaned
          return db.put('ho', 2).then((_) {
            return db.get(1).then((value) {
              expect(value, 'hi');
            });
          });
        });
      });
    });

    var transactionIdAfterOpen = 1;
    test('one currentTransaction', () {
      db.transaction((txn) {
        expect(db.currentTransaction.id, transactionIdAfterOpen + 1);
        return Future.value().then((_) {
          expect(db.currentTransaction.id, transactionIdAfterOpen + 1);
        }).then((_) {
          expect(db.currentTransaction.id, transactionIdAfterOpen + 1);
        });
      }).then((_) {
        expect(db.currentTransaction, null);
      });
    });

    test('two currentTransaction', () {
      db.transaction((txn) {
        expect(db.currentTransaction.id, transactionIdAfterOpen + 1);
      }).then((_) {
        // expect(db.currentTransaction, null);
      });
      return db.transaction((txn) {
        expect(db.currentTransaction.id, transactionIdAfterOpen + 2);
      }).then((_) {
        // expect(db.currentTransaction, null);
      });
    });

    test('two currentTransaction follow', () {
      db.transaction((txn) {
        expect(db.currentTransaction.id, transactionIdAfterOpen + 1);
      }).then((_) {
        expect(db.currentTransaction, null);
        return db.transaction((txn) {
          expect(db.currentTransaction.id, transactionIdAfterOpen + 2);
        }).then((_) {
          expect(db.currentTransaction, null);
        });
      });
    });
  });
}
