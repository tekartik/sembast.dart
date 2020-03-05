library sembast.compat.transaction_test;

// ignore_for_file: deprecated_member_use_from_same_package

// basically same as the io runner but with extra output
import 'dart:async';

import 'package:sembast/sembast.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('compat_transaction', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx, 'compat/transaction.db');
    });

    tearDown(() {
      return db.close();
    });

    test('put/get', () async {
      var putFuture = db.put('hi', 1);
      // It is still null, put has not complete yet!
      expect(await db.get(1), isNull);
      await putFuture;
      expect(await db.get(1), 'hi');
    });

    test('put in transaction', () async {
      final futures = <Future>[];
      futures.add(db.transaction((txn) async {
        await txn.put('hi', 1);
        expect(await txn.get(1), 'hi');
      }));

      // here we are in a transaction so it will wait for the other to finish
      futures.add(db.transaction((txn) async {
        expect(await txn.get(1), 'hi');
      }));

      // here the value should not be loaded yet
      expect(await db.get(1), isNull);
      return Future.wait(futures);
    });

    test('put and throw', () {
      return db.transaction((Transaction txn) {
        return txn.put('hi', 1).then((_) {
          // still here
          return txn.get(1).then((value) {
            expect(value, 'hi');
          }).then((_) {
            throw 'some failure';
          });
        });
      }).catchError((err) {
        expect(err, 'some failure');
      }).then((_) {
        // put something else to make sure the txn has been cleaned
        return db.put('ho', 2).then((_) {
          return db.get(1).then((value) {
            expect(value, null);
          });
        });
      });
    });

    test('put no await', () async {
      Transaction transaction;
      await db.transaction((txn) {
        transaction = txn;
      });
      try {
        await transaction.put('test');
        fail('first put should fail');
      } on StateError catch (_) {}
    });
  });
}
