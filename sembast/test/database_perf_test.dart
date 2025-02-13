library;

import 'dart:async';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext, 10);
}

void defineTests(
  DatabaseTestContext ctx,
  int putCount, {
  int randomCount = 10,
  int randomChoices = 10,
}) {
  group('perf', () {
    late Database db;

    setUp(() async {
      db = await setupForTest(ctx, 'compat/perf.db');
    });

    tearDown(() {
      return db.close();
    });

    var store = StoreRef<int, String>.main();
    test('put/read $putCount', () async {
      final futures = <Future>[];
      for (var i = 0; i < putCount; i++) {
        futures.add(store.record(i).put(db, 'value $i'));
        // let it breathe
        //print(i);
        await Future<void>.delayed(Duration.zero);
      }
      await Future.wait(futures);
      expect(await store.count(db), putCount);
    });

    test('put/read in transaction $putCount', () async {
      await db.transaction((txn) async {
        final futures = <Future>[];
        for (var i = 0; i < putCount; i++) {
          futures.add(store.record(i).put(txn, 'value $i'));
        }
        await Future.wait(futures);
        expect(await store.count(txn), putCount);
      });
      expect(await store.count(db), putCount);
    });
  });
}
