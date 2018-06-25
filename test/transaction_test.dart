library sembast.transaction_test;

// basically same as the io runner but with extra output
import 'dart:async';

import 'package:sembast/sembast.dart';
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
      await db.transaction((txn) async {
        await txn.put("hi", 1);
        await txn.mainStore.clear();
        expect(await txn.get(1), isNull);
      });
    });

    test('put in transaction', () async {
      List<Future> futures = [];
      futures.add(db.transaction((txn) async {
        await txn.put("hi", 1);
        expect(await txn.get(1), "hi");
      }));

      // here we are in a transaction so it will wait for the other to finish
      futures.add(db.transaction((txn) async {
        expect(await txn.get(1), "hi");
      }));

      // here the value should not be loaded yet
      expect(await db.get(1), isNull);
      return Future.wait(futures);
    });

    test('transaction and read', () async {
      List<Future> futures = [];
      var completer1 = new Completer();
      var completer2 = new Completer();
      futures.add(db.transaction((txn) async {
        expect(await txn.containsKey(1), isFalse);

        await txn.put("hi", 1);
        completer1.complete();

        expect(await txn.get(1), "hi");

        var records = await txn.findRecords(null);
        expect(records.length, 1);

        records = await txn.records.toList();
        expect(records.length, 1);

        var count = await txn.count(null);
        expect(count, 1);

        expect(await txn.containsKey(1), isTrue);

        await completer2.future;
      }));

      await completer1.future;

      expect(await db.get(1), isNull);
      expect(await db.mainStore.getRecord(1), isNull);
      var records = await db.findRecords(null);
      expect(records.length, 0);

      records = await db.records.toList();
      expect(records.length, 0);

      var count = await db.count(null);
      expect(count, 0);

      expect(await db.containsKey(1), isFalse);

      // here we are in a transaction so it will wait for the other to finish
      futures.add(db.transaction((txn) async {
        expect(await txn.get(1), "hi");
      }));

      completer2.complete();

      return Future.wait(futures);
    });

    test('put and throw', () {
      return db.transaction((Transaction txn) {
        return txn.put("hi", 1).then((_) {
          // still here
          return txn.get(1).then((value) {
            expect(value, "hi");
          }).then((_) {
            throw "some failure";
          });
        });
      }).catchError((err) {
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
  });
}
