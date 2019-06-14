library sembast.store_test;

// basically same as the io runner but with extra output
import 'package:sembast/src/api/sembast.dart';
import 'package:sembast/src/common_import.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('query', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx);
    });

    tearDown(() {
      return db.close();
    });

    test('onSnapshots', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);
      int index = 0;
      var completer = Completer();

      // When starting listening the record does not exists yet
      var query = store.query();
      var sub = query.onSnapshots(db).listen((snapshots) {
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

      // delete
      await record.delete(db);
      await completer.future;
      await sub.cancel();
      expect(index, 5);
    });

    test('onSnapshotExisting', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);
      await record.put(db, 'test');
      expect((await record.onSnapshot(db).first).value, 'test');
    });

    test('onSnapshot 2 records', () async {
      var store = StoreRef<int, String>.main();
      var record1 = store.record(1);
      var record2 = store.record(2);
      var future1 = record1.onSnapshot(db).skip(1).first;
      var future2 = record2.onSnapshot(db).skip(1).first;
      await db.transaction((txn) async {
        await record1.put(txn, 'test1');
        await record2.put(txn, 'test2');
      });
      expect((await future1).value, 'test1');
      expect((await future2).value, 'test2');
    });
  });
}
