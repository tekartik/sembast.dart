library sembast.database_perf_test;

// basically same as the io runner but with extra output
import 'dart:async';
import 'dart:math';

import 'package:sembast/sembast.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext, 10);
}

void defineTests(DatabaseTestContext ctx, int putCount,
    {int randomCount = 10, int randomChoices = 10}) {
  group('perf', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx);
    });

    tearDown(() {
      return db.close();
    });

    test('put/read $putCount', () async {
      List<Future> futures = [];
      for (int i = 0; i < putCount; i++) {
        futures.add(db.put("value $i", i));
        // let it breathe
        //print(i);
        await Future.delayed(const Duration());
      }
      await Future.wait(futures).then((_) {
        return db.count().then((int count) {
          expect(count, putCount);
        });
      });
    });

    test('put/read in transaction $putCount', () {
      return db.transaction((txn) {
        List<Future> futures = [];
        for (int i = 0; i < putCount; i++) {
          futures.add(txn.put("value $i", i));
        }
        return Future.wait(futures);
      }).then((_) {
        return db.count().then((int count) {
          expect(count, putCount);
        });
      });
    });
  });

  group('perf', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx);
    });

    tearDown(() {
      return db.close();
    });

    test('random $randomCount', () async {
      Random random = Random();

      for (int i = 0; i < randomCount; i++) {
        int actionChoice = random.nextInt(5);
        String store = "store ${random.nextInt(randomChoices)}";
        int key = random.nextInt(randomChoices);
        switch (actionChoice) {
          // put
          case 0:
            // delete
            //print("delete");
            await db.getStore(store).delete(key);
            break;
          default:
            //print("put");
            await db.getStore(store).put("test", key);
            break;
        }
        // let it breathe
        //print(i);
        await Future.delayed(const Duration(milliseconds: 0));
      }
    });
  });
}
