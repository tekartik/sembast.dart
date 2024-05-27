library sembast_test.listener_test;

// basically same as the io runner but with extra output
// ignore_for_file: implementation_imports
import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/database_impl.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('record_listener', () {
    late Database db;

    setUp(() async {
      db = await setupForTest(ctx, 'record_listener.db');
    });

    tearDown(() {
      return db.close();
    });

    test('Record.onSnapshot', () async {
      var database = getDatabase(db);
      var store = StoreRef<int, String>.main();
      var record = store.record(1);

      expect(database.listener.isEmpty, isTrue);
      var sub = record.onSnapshot(db).listen((snapshot) {});
      expect(database.listener.isNotEmpty, isTrue);
      var sub2 = record.onSnapshot(db).listen((snapshot) {});
      await sub.cancel();
      expect(database.listener.isNotEmpty, isTrue);
      await sub2.cancel();
      expect(database.listener.isEmpty, isTrue);
    });

    test('Record.onSnapshot.listen', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);

      var done = Completer<void>();
      var sub = record.onSnapshot(db).listen((snapshot) {
        // devPrint('onSnapshot: $snapshot');
        if (snapshot?.value == 'test2') {
          done.complete();
        }
      });
      unawaited(record.add(db, 'test1'));
      unawaited(record.delete(db));
      unawaited(record.add(db, 'test2'));
      await done.future;
      await sub.cancel();
    });

    test('Record.onSnapshot.multi', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);

      var done1 = Completer<void>();
      var done2 = Completer<void>();
      var done3 = Completer<void>();
      late StreamSubscription sub1, sub2, sub3;
      sub1 = record.onSnapshot(db).listen((snapshot) {
        if (snapshot?.value == 'test1') {
          done1.complete();
          sub1.cancel();
        }
      });
      sub2 = record.onSnapshot(db).listen((snapshot) {
        if (snapshot?.value == 'test2') {
          done2.complete();
          sub2.cancel();
        }
      });
      unawaited(record.add(db, 'test1'));
      await done1.future;
      sub3 = record.onSnapshot(db).listen((snapshot) {
        if (snapshot?.value == 'test1') {
          done3.complete();
          sub3.cancel();
        }
      });
      unawaited(record.delete(db));
      unawaited(record.add(db, 'test2'));
      await done2.future;
      await done3.future;
    });

    test('Store.onSnapshots.listen add', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);

      var done = Completer<void>();
      var snapshotLists = <List>[];
      var sub = store.query().onSnapshots(db).listen((snapshots) {
        snapshotLists.add(snapshots);
        if (snapshots.isNotEmpty) {
          done.complete();
        }
      });
      unawaited(record.add(db, 'test1'));
      await done.future;
      expect(snapshotLists.length, 2);
      await sub.cancel();
    });

    test('Store.onSnapshots.listen delete', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);

      var done = Completer<void>();
      var snapshotLists = <List>[];
      await record.add(db, 'test1');
      var sub = store.query().onSnapshots(db).listen((snapshots) {
        snapshotLists.add(snapshots);
        if (snapshots.isEmpty) {
          done.complete();
        }
      });
      unawaited(record.delete(db));
      await done.future;
      expect(snapshotLists.length, 2);
      await sub.cancel();
    });

    test('Store.onSnapshots.listen put', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);

      var done = Completer<void>();
      var snapshotLists = <List>[];
      await record.add(db, 'test1');
      var sub = store.query().onSnapshots(db).listen((snapshots) {
        snapshotLists.add(snapshots);
        if (snapshots.first.value == 'test2') {
          done.complete();
        }
      });
      unawaited(record.put(db, 'test2'));
      await done.future;
      expect(snapshotLists.length, 2);
      await sub.cancel();
    });

    test('Query.onSnapshots.listen', () async {
      var store = StoreRef<int, String>.main();

      var done = Completer<void>();
      var sub = store
          .query(finder: Finder(sortOrders: [SortOrder(Field.value)]))
          .onSnapshots(db)
          .listen((snapshots) {
        if (snapshots.length == 3) {
          expect(snapshots.map((e) => e.key), [1, 3, 2]);
          done.complete();
        }
      });
      unawaited(store.add(db, 'test1'));
      unawaited(store.add(db, 'test3'));
      unawaited(store.add(db, 'test2'));
      await done.future;
      await sub.cancel();
    });

    test('Record.onSnapshotDbClose', () async {
      var database = getDatabase(db);
      var store = StoreRef<int, String>.main();
      var record = store.record(1);

      var completer = Completer<void>();

      record.onSnapshot(db).listen((snapshot) {
        fail('should be closed');
      }, onDone: () {
        completer.complete();
      });
      expect(database.listener.isNotEmpty, isTrue);
      await db.close();
      expect(database.listener.isEmpty, isTrue);
      await completer.future;
    });

    test('Query.onSnapshots', () async {
      var database = getDatabase(db);
      var store = StoreRef<int, String>.main();
      var query = store.query();

      expect(database.listener.isEmpty, isTrue);
      var sub = query.onSnapshots(db).listen((snapshot) {});
      expect(database.listener.isNotEmpty, isTrue);
      var sub2 = query.onSnapshots(db).listen((snapshot) {});
      await sub.cancel();
      expect(database.listener.isNotEmpty, isTrue);
      await sub2.cancel();
      expect(database.listener.isEmpty, isTrue);
    });

    test('Query.onSnapshots.multi', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);

      var done1 = Completer<void>();
      var done2 = Completer<void>();
      var done3 = Completer<void>();
      late StreamSubscription sub1, sub2, sub3;
      sub1 = store.query().onSnapshot(db).listen((snapshot) {
        if (snapshot?.value == 'test1') {
          done1.complete();
          sub1.cancel();
        }
      });
      sub2 = store.query().onSnapshot(db).listen((snapshot) {
        if (snapshot?.value == 'test2') {
          done2.complete();
          sub2.cancel();
        }
      });
      unawaited(record.add(db, 'test1'));
      await done1.future;
      sub3 = store.query().onSnapshot(db).listen((snapshot) {
        if (snapshot?.value == 'test1') {
          done3.complete();
          sub3.cancel();
        }
      });
      unawaited(record.delete(db));
      unawaited(record.add(db, 'test2'));
      await done2.future;
      await done3.future;
    });

    test('Query.onSnapshotDbClose', () async {
      var database = getDatabase(db);
      var store = StoreRef<int, String>.main();
      var query = store.query();

      var completer = Completer<void>();
      query.onSnapshots(db).listen((snapshots) {
        fail('should be closed');
      }, onDone: () {
        completer.complete();
      });
      expect(database.listener.isNotEmpty, isTrue);
      await db.close();
      expect(database.listener.isEmpty, isTrue);
      await completer.future;
    });

    test('Query.onSnapshotsDone', () async {
      var database = getDatabase(db);
      var store = StoreRef<int, String>.main();
      var record = store.record(1);
      await record.put(db, 'test');
      var query = store.query(
          finder: Finder(filter: Filter.custom((record) => throw 'crash')));

      var completer = Completer<void>();
      query.onSnapshots(db).listen((snapshot) {
        fail('should be closed');
      }, onDone: () {
        // devPrint('onDone');
        completer.complete();
      });
      expect(database.listener.isNotEmpty, isTrue);
      var ctlr = database.listener
          .getStore(store)!
          .getStoreListenerControllers<int, String>()
          .first;
      ctlr.close();

      await completer.future;
      // devPrint(list);
      expect(database.listener.isEmpty, isTrue);
    });

    test('FilterRef.onCount', () async {
      var database = getDatabase(db);
      var store = StoreRef<int, String>.main();

      expect(database.listener.isEmpty, isTrue);
      var sub = store.onCount(db).listen((snapshot) {});
      expect(database.listener.isNotEmpty, isTrue);
      var sub2 = store.onCount(db).listen((snapshot) {});
      await sub.cancel();
      expect(database.listener.isNotEmpty, isTrue);
      await sub2.cancel();
      expect(database.listener.isEmpty, isTrue);
    });
  });
}
