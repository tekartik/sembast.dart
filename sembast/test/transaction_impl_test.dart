library sembast.transaction_test;

// basically same as the io runner but with extra output
import 'dart:async';

import 'package:sembast/src/database_impl.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('transaction_impl', () {
    late SembastDatabase db;

    setUp(() async {
      db = await setupForTest(ctx, 'compat/transaction_impl.db')
          as SembastDatabase;
    });

    tearDown(() {
      return db.close();
    });

    var store = StoreRef<int, String>.main();
    var record = store.record(1);

    test('put/get', () {
      final futures = <Future>[];
      expect(db.currentTransaction, isNull);
      futures.add(record.put(db, 'hi'));
      // expect(db.currentTransaction, isNull);
      // here the value should not be loaded yet
      futures.add(record.get(db).then((value) {
        //expect(db.currentTransaction, isNull);
        expect(value, null);
      } as FutureOr<dynamic> Function(String?)));
      return Future.wait(futures);
    });

    var transactionIdAfterOpen = 1;
    test('one currentTransaction', () {
      db.transaction((txn) {
        expect(db.currentTransaction!.id, transactionIdAfterOpen + 1);
        return Future.value().then((_) {
          expect(db.currentTransaction!.id, transactionIdAfterOpen + 1);
        }).then((_) {
          expect(db.currentTransaction!.id, transactionIdAfterOpen + 1);
        } as FutureOr<_> Function(Null));
      }).then((_) {
        expect(db.currentTransaction, null);
      } as FutureOr<_> Function(Null));
    });

    test('two currentTransaction', () {
      db.transaction((txn) {
        expect(db.currentTransaction!.id, transactionIdAfterOpen + 1);
      }).then((_) {
        // expect(db.currentTransaction, null);
      } as FutureOr<_> Function(Null));
      return db.transaction((txn) {
        expect(db.currentTransaction!.id, transactionIdAfterOpen + 2);
      }).then((_) {
        // expect(db.currentTransaction, null);
      } as FutureOr<_> Function(Null));
    });

    test('two currentTransaction follow', () {
      db.transaction((txn) {
        expect(db.currentTransaction!.id, transactionIdAfterOpen + 1);
      }).then((_) {
        expect(db.currentTransaction, null);
        return db.transaction((txn) {
          expect(db.currentTransaction!.id, transactionIdAfterOpen + 2);
        }).then((_) {
          expect(db.currentTransaction, null);
        } as FutureOr<_> Function(Null));
      } as FutureOr<_> Function(Null));
    });
  });
}
