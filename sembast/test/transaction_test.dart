library sembast.transaction_test;

// basically same as the io runner but with extra output
import 'dart:async';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('transaction', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx, 'transaction.db');
    });

    tearDown(() {
      return db.close();
    });

    test('put/get', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);
      var putFuture = record.put(db, "hi");
      // It is still null, put has not complete yet!
      expect(await record.get(db), isNull);
      await putFuture;
      expect(await record.get(db), "hi");
    });

    test('put/clear/get in transaction', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);

      await db.transaction((txn) async {
        await record.put(txn, "hi");
        await store.delete(txn);
        expect(await record.get(db), isNull);
      });
    });

    test('put in transaction', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);

      List<Future> futures = [];
      futures.add(db.transaction((txn) async {
        await record.put(txn, 'hi');
        expect(await record.get(txn), "hi");
      }));

      // here we are in a transaction so it will wait for the other to finish
      futures.add(db.transaction((txn) async {
        expect(await record.get(txn), "hi");
      }));

      // here the value should not be loaded yet
      expect(await record.get(db), isNull);
      return Future.wait(futures);
    });

    test('transaction and read', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);

      List<Future> futures = [];
      var completer1 = Completer();
      var completer2 = Completer();
      futures.add(db.transaction((txn) async {
        expect(await record.exists(txn), isFalse);

        await record.put(txn, 'hi');
        completer1.complete();

        expect(await record.get(txn), "hi");

        var records = await store.find(txn);
        expect(records.length, 1);

        records = await store.stream(txn).toList();
        expect(records.length, 1);

        var count = await store.count(txn);
        expect(count, 1);

        expect(await record.exists(txn), isTrue);

        await completer2.future;
      }));

      await completer1.future;

      expect(await record.get(db), isNull);
      var records = await store.find(db);
      expect(records.length, 0);

      records = await store.stream(db).toList();
      expect(records.length, 0);

      var count = await store.count(db);
      expect(count, 0);

      expect(await record.exists(db), isFalse);

      // here we are in a transaction so it will wait for the other to finish
      futures.add(db.transaction((txn) async {
        expect(await record.get(txn), "hi");
      }));

      completer2.complete();

      return Future.wait(futures);
    });

    test('put and throw', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);

      await db.transaction((Transaction txn) async {
        await record.put(txn, "hi");
        expect(await record.get(txn), "hi");

        throw "some failure";
      }).catchError((err) {
        expect(err, "some failure");
      });
      expect(await record.get(db), isNull);

      // put something else to make sure the txn has been cleaned
      await store.record(2).put(db, 'ho');
      expect(await record.get(db), isNull);
    });

    test('put no await', () async {
      Transaction transaction;
      await db.transaction((txn) {
        transaction = txn;
      });
      try {
        await StoreRef.main().add(transaction, 'test');
        fail('first put should fail');
      } on StateError catch (_) {}
    });
  });
}
