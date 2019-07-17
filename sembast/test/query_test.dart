library sembast.store_test;

// basically same as the io runner but with extra output

import 'package:sembast/src/common_import.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('query', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx, 'query.db');
    });

    tearDown(() {
      return db.close();
    });

    test('put/query timing', () async {
      var record = StoreRef<int, String>.main().record(1);
      var query = record.store.query();
      var future1 = query.getSnapshots(db);
      await record.put(db, 'test');
      var future2 = query.getSnapshots(db);
      await record.put(db, 'test2');
      var future3 = query.getSnapshots(db);
      await record.delete(db);
      var future4 = query.getSnapshots(db);
      expect(await future1, isEmpty);
      expect((await future2).first.value, 'test');
      expect((await future3).first.value, 'test2');
      expect(await future4, isEmpty);
    });

    test('getSnapshot(s)', () async {
      var store = StoreRef<int, String>.main();
      var record1 = store.record(1);
      var record2 = store.record(2);
      await record1.put(db, 'test');
      await record2.put(db, 'test2');
      var query = store.query();
      expect((await query.getSnapshots(db)).map((snapshot) => snapshot.key),
          [1, 2]);
      expect((await query.getSnapshot(db)).key, 1);
      query = store.query(
          finder: Finder(filter: Filter.equals(Field.value, 'test2')));
      expect(
          (await query.getSnapshots(db)).map((snapshot) => snapshot.key), [2]);
      expect((await query.getSnapshot(db)).key, 2);
      query = store.query(
          finder: Finder(filter: Filter.equals(Field.value, 'test3')));
      expect(
          (await query.getSnapshots(db)).map((snapshot) => snapshot.key), []);
      expect((await query.getSnapshot(db)), isNull);
    });

    test('put/on timing', () async {
      var record = StoreRef<int, String>.main().record(1);
      var query = record.store.query();
      var future1 = query.onSnapshots(db).first;
      await record.put(db, 'test');
      var future2 = query.onSnapshots(db).first;
      await record.put(db, 'test2');
      var future3 = query.onSnapshots(db).first;
      await record.delete(db);
      var future4 = query.onSnapshots(db).first;
      expect(await future1, isEmpty);
      expect((await future2), hasLength(1));
      expect((await future2).first.value, 'test');
      expect((await future3).first.value, 'test2');
      expect(await future4, isEmpty);
    });

    test('onSnapshots', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);
      int index = 0;
      var completer = Completer();

      // When starting listening the record does not exists yet
      var query = store.query();
      var sub = query.onSnapshots(db).listen((snapshots) {
        // devPrint('$index $snapshots');
        var first = snapshots.isNotEmpty ? snapshots.first : null;
        int key = first?.key;
        String value = first?.value;

        if (index == 0) {
          expect(snapshots, isEmpty);
        } else if (index == 1) {
          expect(snapshots.length, 1);
          expect(key, 1);
          expect(value, 'test');
        } else if (index == 2) {
          expect(snapshots.length, 2);
          expect(key, 1);
          expect(value, 'test');
        } else if (index == 3) {
          expect(snapshots.length, 2);
          expect(key, 1);
          expect(value, 'test2');
        } else if (index == 4) {
          expect(snapshots.length, 1);
          expect(key, 2);
          expect(value, 'test3');
          // expect(snapshots, isEmpty);
        }
        if (++index == 5) {
          completer.complete();
        }
      });
      //await Future.delayed(Duration(milliseconds: 1));
      // create
      await record.put(db, 'test');

      // add
      await store.record(2).put(db, 'test3');
      expect(await query.getSnapshots(db), hasLength(2));

      // update
      await record.put(db, 'test2');

      // delete
      await record.delete(db);
      await completer.future;
      await sub.cancel();
      expect(index, 5);
    });

    test('onSnapshotsWithFinder', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);
      int index = 0;
      var completer = Completer();

      // When starting listening the record does not exists yet
      var query = store.query(
          finder: Finder(
              filter: Filter.greaterThan(Field.value, 'test'),
              limit: 1,
              sortOrders: [SortOrder(Field.value)]));
      expect(await query.getSnapshots(db), hasLength(0));

      var sub = query.onSnapshots(db).listen((snapshots) {
        var first = snapshots.isNotEmpty ? snapshots.first : null;
        int key = first?.key;
        String value = first?.value;

        if (index == 0) {
          expect(snapshots, isEmpty);
        } else if (index == 1) {
          expect(snapshots.length, 1);
          expect(key, 1);
          expect(value, 'test2');
        } else if (index == 2) {
          expect(snapshots.length, 1);
          expect(key, 2);
          expect(value, 'test1');
        } else if (index == 3) {
          expect(snapshots.length, 1);
          expect(key, 1);
          expect(value, 'test1');
        } else if (index == 4) {
          expect(snapshots.length, 1);
          expect(key, 2);
          expect(value, 'test1');
        }
        if (++index == 5) {
          completer.complete();
        }
      });
      //await Future.delayed(Duration(milliseconds: 1));
      // create
      await record.put(db, 'test2');
      // add
      await store.record(2).put(db, 'test1');
      expect(await query.getSnapshots(db), hasLength(1));

      // update
      await record.put(db, 'test1');

      // change that does not affect the query
      await store.record(3).put(db, 'dummy not in query');

      // delete
      await record.delete(db);
      await completer.future;
      await sub.cancel();
      expect(index, 5);
    });

    test('onSnapshotsExisting', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);
      await record.put(db, 'test');
      expect((await store.query().onSnapshots(db).first).first.value, 'test');
    });

    test('onSnapshotsBeforeCreationAndUpdate', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);
      var future1 = store.query().onSnapshots(db).first;
      await record.put(db, 'test');
      var future2 = store.query().onSnapshots(db).first;
      await record.put(db, 'test2');
      var future3 = store.query().onSnapshots(db).first;

      expect(await future1, isEmpty);
      expect((await future2).first.value, 'test');
      expect((await future2).length, 1);
      expect((await future3).first.value, 'test2');
    });

    test('onSnapshotsWithFinderBeforeCreationAndUpdate', () async {
      var store = StoreRef<int, String>.main();
      var record1 = store.record(1);
      var record2 = store.record(2);
      var query = store.query(
          finder: Finder(filter: Filter.greaterThan(Field.value, 'abc')));
      var future1 = query.onSnapshots(db).first;
      await record1.put(db, 'abcd');
      var future2 = query.onSnapshots(db).first;
      await record2.put(db, 'ab');
      var future3 = query.onSnapshots(db).first;
      await record2.put(db, 'abd');
      var future4 = query.onSnapshots(db).first;
      await record1.put(db, 'ab');
      var future5 = query.onSnapshots(db).first;

      expect(await future1, isEmpty);

      expect((await future2).length, 1);
      expect((await future2).first.value, 'abcd');

      expect((await future3).length, 1);
      expect((await future3).first.value, 'abcd');

      expect((await future4).length, 2);
      expect((await future4)[1].value, 'abd');
      expect((await future4)[1].value, 'abd');

      expect((await future4).first.value, 'abcd');
      expect((await future5).first.value, 'abd');
      expect((await future5).length, 1);
    });

    test('onSnapshotsExistingAfterOpen', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);
      await record.put(db, 'test');
      await db.close();
      db = await ctx.factory.openDatabase(db.path);
      expect((await store.query().onSnapshots(db).first).first.value, 'test');
    });

    test('onSnapshots 2 records', () async {
      var store = StoreRef<int, String>.main();
      var record1 = store.record(1);
      var record2 = store.record(2);
      var future1 = store.query().onSnapshots(db).first;
      await db.transaction((txn) async {
        await record1.put(txn, 'test1');
        await record2.put(txn, 'test2');
      });
      var future2 = store.query().onSnapshots(db).first;
      expect(await future1, isEmpty);
      expect((await future2)[0].value, 'test1');
      expect((await future2)[1].value, 'test2');
    });
  });
}
