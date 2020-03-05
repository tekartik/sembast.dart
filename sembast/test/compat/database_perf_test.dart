library sembast.database_perf_test;

// ignore_for_file: deprecated_member_use_from_same_package
import 'dart:async';

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
      db = await setupForTest(ctx, 'compat/perf.db');
    });

    tearDown(() {
      return db.close();
    });

    test('put/read $putCount', () async {
      final futures = <Future>[];
      for (var i = 0; i < putCount; i++) {
        futures.add(db.put('value $i', i));
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
        final futures = <Future>[];
        for (var i = 0; i < putCount; i++) {
          futures.add(txn.put('value $i', i));
        }
        return Future.wait(futures);
      }).then((_) {
        return db.count().then((int count) {
          expect(count, putCount);
        });
      });
    });
  });
}
