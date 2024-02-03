library sembast.store_test;

// basically same as the io runner but with extra output
// ignore_for_file: implementation_imports
import 'package:sembast/src/common_import.dart';

import 'test_common.dart';

void main() {
  defineRecordTests(memoryDatabaseContext);
}

void defineRecordTests(DatabaseTestContext ctx) {
  group('record', () {
    late Database db;

    setUp(() async {
      db = await setupForTest(ctx, 'record.db');
    });

    tearDown(() {
      return db.close();
    });

    test('equals', () {
      var record1 = StoreRef<int?, Object?>.main().record(1);
      var record2 = StoreRef<int?, Object?>.main().record(1);
      expect(record1, record2);
      expect(record1.hashCode, record2.hashCode);
      expect(record1, isNot(StoreRef<int, Object?>('test').record(1)));
      expect(record1, isNot(StoreRef<int, Object?>.main().record(2)));
      expect(record1, StoreRef<int, Object?>.main().record(1));
      expect(record1, isNot(StoreRef<String?, Object?>.main().record('test')));
      expect(
          StoreRef<String, Object>.main().record('test'),
          StoreRef<String?, Object?>.main().record((StringBuffer()
                ..write('te')
                ..write('st'))
              .toString()));
    });

    test('put/get timing', () async {
      // No random timing
      setDatabaseCooperator(db, null);

      var record = StoreRef<int, String>.main().record(1);
      var future1 = record.get(db);
      await record.put(db, 'test');
      var future2 = record.get(db);
      await record.put(db, 'test2');
      var future3 = record.get(db);
      await record.delete(db);
      var future4 = record.get(db);
      expect(await future1, isNull);
      expect(await future2, 'test');
      expect(await future3, 'test2');
      expect(await future4, isNull);
    });

    test('put/on timing', () async {
      // No random timing
      setDatabaseCooperator(db, null);

      var record = StoreRef<int, String>.main().record(1);
      var future1 = record.onSnapshot(db).first;
      await record.put(db, 'test');
      var future2 = record.onSnapshot(db).first;
      await record.put(db, 'test2');
      var future3 = record.onSnapshot(db).first;
      await record.delete(db);
      var future4 = record.onSnapshot(db).first;
      expect(await future1, isNull);
      expect((await future2)!.value, 'test');
      expect((await future3)!.value, 'test2');
      expect(await future4, isNull);
    });

    void expectSnapshot<K, V>(RecordSnapshot<K, V> snapshot, K key, V value) {
      expect(snapshot.key, key);
      expect(snapshot.value, value);
    }

    test('put/get_sync ', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);
      var records = store.records([1]);
      expect(record.existsSync(db), isFalse);
      expect(record.getSync(db), isNull);
      expect(record.getSnapshotSync(db), isNull);
      expect(records.getSnapshotsSync(db), [null]);
      var step1 = Completer<void>();
      var step2 = Completer<void>();

      var txnFuture = db.transaction((txn) async {
        await record.put(txn, 'test');
        step1.complete();
        expect(record.existsSync(txn), isTrue);
        expect(record.getSync(txn), 'test');
        expectSnapshot(record.getSnapshotSync(txn)!, 1, 'test');
        expectSnapshot(records.getSnapshotsSync(txn).first!, 1, 'test');
        await step2.future;
      });
      expect(record.existsSync(db), isFalse);
      expect(record.getSync(db), isNull);
      expect(record.getSnapshotSync(db), isNull);
      expect(records.getSnapshotsSync(db), [null]);
      await step1.future;
      step2.complete();

      await txnFuture;
      expect(record.existsSync(db), isTrue);
      expect(record.getSync(db), 'test');
      expectSnapshot(record.getSnapshotSync(db)!, 1, 'test');
      expectSnapshot(records.getSnapshotsSync(db).first!, 1, 'test');
    });

    test('add', () async {
      var record = StoreRef<int, String>.main().record(1);
      expect(await record.add(db, 'test'), 1);
      expect(await record.add(db, 'test'), isNull);
      await record.delete(db);
      expect(await record.add(db, 'test'), 1);
      expect(await record.add(db, 'test'), isNull);
    });

    test('put null', () async {
      var record = StoreRef<int, String?>.main().record(1);
      await record.put(db, 'not null');
      await expectLater(() => record.put(db, null), throwsArgumentError);
      await record.put(db, 'not null');
    });
    test('update', () async {
      var record = StoreRef<int, String>.main().record(1);
      expect(await record.update(db, 'test1'), isNull);
      expect(await record.add(db, 'test'), 1);
      expect(await record.update(db, 'test1'), 'test1');
    });

    test('delete', () async {
      var record = StoreRef<int, String>.main().record(1);
      await record.put(db, 'test1');
      expect(await record.delete(db), 1);
      expect(await record.delete(db), isNull);
    });

    test('get closed', () async {
      await db.close();
      var record = StoreRef<int, String>.main().record(1);
      try {
        expect(await record.get(db), isNull);
        fail('should fail');
      } on DatabaseException catch (e) {
        expect(e.code, DatabaseException.errDatabaseClosed);
      }
    });
    test('onSnapshot', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);
      var index = 0;
      var completer = Completer<void>();

      // When starting listening the record does not exists yet
      var sub = record.onSnapshot(db).listen((snapshot) {
        //return;
        final key = snapshot?.key;
        final value = snapshot?.value;

        if (index == 0) {
          expect(snapshot, isNull);
        } else if (index == 1) {
          expect(key, 1);
          expect(value, 'test');
        } else if (index == 2) {
          expect(key, 1);
          expect(value, 'test2');
        } else if (index == 3) {
          expect(snapshot, isNull);
        }
        if (++index == 4) {
          completer.complete();
        }
      });
      //await Future.delayed(Duration(milliseconds: 1));
      // create
      await record.put(db, 'test');
      // dummy
      await store.record(2).put(db, 'test3');

      // update
      await record.put(db, 'test2');

      // delete
      await record.delete(db);
      await completer.future;
      await sub.cancel();
      expect(index, 4);
    });

    test('onSnapshot.closeDb', () async {
      var record = intMapStoreFactory.store().record(1);
      try {
        await record
            .onSnapshot(db)
            .toList()
            .timeout(const Duration(milliseconds: 1));
        fail('should timeout');
      } on TimeoutException catch (_) {}

      var completer = Completer<void>();
      var doneCompleter = Completer<void>();
      // Wait for first event before closing the db
      var subscription = record.onSnapshot(db).listen((snapshot) {
        completer.complete();
      }, onDone: () {
        doneCompleter.complete();
      });
      await completer.future;
      await db.close();
      await doneCompleter.future;
      await subscription.cancel();
    });

    test('onSnapshotExisting', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);
      await record.put(db, 'test');
      expect((await record.onSnapshot(db).first)!.value, 'test');
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
      expect((await future1)!.value, 'test1');
      expect((await future2)!.value, 'test2');
    });

    test('record.onSnapshotSync null', () async {
      // Key is an int, value is an int
      var store = StoreRef<int, int>.main();
      // Key is 1
      var record = store.record(1);

      var got = false;
      var completer = Completer<void>();
      RecordSnapshot<int, int>? snapshot;
      var subscription = record.onSnapshotSync(db).listen((event) {
        snapshot = event;
        got = true;
        if (snapshot != null) {
          completer.complete();
        }
      });

      expect(got, false);
      scheduleMicrotask(() {
        expect(snapshot, isNull);
        expect(got, true);
      });
      await record.put(db, 2);
      await completer.future;
      expect(snapshot!.value, 2);

      await subscription.cancel();
    });

    test('record.onSnapshotSync value', () async {
      // Key is an int, value is an int
      var store = StoreRef<int, int>.main();
      // Key is 1
      var record = store.record(1);
      await record.put(db, 2);
      var got = false;
      RecordSnapshot<int, int>? snapshot;
      var subscription = record.onSnapshotSync(db).listen((event) {
        snapshot = event;
        got = true;
      });

      expect(got, false);
      var completer = Completer<void>();
      scheduleMicrotask(() {
        expect(snapshot!.value, 2);
        expect(got, true);
        completer.complete();
      });
      await completer.future;
      await subscription.cancel();
    });

    test('records.onSnapshotsSync null', () async {
      // Key is an int, value is an int
      var store = StoreRef<int, int>.main();
      // Key is 1

      var records = store.records([1, 2]);
      var got = false;
      List<RecordSnapshot<int, int>?>? snapshots;
      var firstCompleter = Completer<void>();
      var completer = Completer<void>();
      var subscription = records.onSnapshotsSync(db).listen((event) {
        print(event);
        snapshots = event;
        got = true;
        // Unfortunately we don't get the two snapshots at the same time...
        if (snapshots![0] != null && snapshots![1] != null) {
          completer.complete();
        }
      });

      expect(got, false);
      // Schedule 2 microtask one for the main stream, one for the sub stream
      scheduleMicrotask(() {
        scheduleMicrotask(() {
          expect(snapshots, [null, null]);
          expect(got, true);
          firstCompleter.complete();
        });
      });

      await firstCompleter.future;

      await db.transaction((transaction) async {
        await records[0].put(transaction, 3);
        await records[1].put(transaction, 4);
      });
      await completer.future;
      expect(snapshots!.map((e) => e!.value), [3, 4]);

      await subscription.cancel();
    });
  });
}
