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
  });
}
