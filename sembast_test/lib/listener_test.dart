library sembast_test.listener_test;

import 'package:pedantic/pedantic.dart';

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

      var done = Completer();
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

    test('Store.onSnapshots.listen', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);

      var done = Completer();
      var sub = store.query().onSnapshots(db).listen((snapshots) {
        // devPrint('onSnapshots: $snapshots');
        if (snapshots.isNotEmpty && snapshots.first.value == 'test2') {
          done.complete();
        }
      });
      unawaited(record.add(db, 'test1'));
      unawaited(record.delete(db));
      unawaited(record.add(db, 'test2'));
      await done.future;
      await sub.cancel();
    });

    test('Query.onSnapshots.listen', () async {
      var store = StoreRef<int, String>.main();

      var done = Completer();
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

      var completer = Completer();

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

    test('Query.onSnapshotDbClose', () async {
      var database = getDatabase(db);
      var store = StoreRef<int, String>.main();
      var query = store.query();

      var completer = Completer();
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

      var completer = Completer();
      query.onSnapshots(db).listen((snapshot) {
        fail('should be closed');
      }, onDone: () {
        // devPrint('onDone');
        completer.complete();
      });
      expect(database.listener.isNotEmpty, isTrue);
      var ctlr = database.listener
          .getStore(store)!
          .getQueryListenerControllers()
          .first;
      ctlr.close();

      await completer.future;
      // devPrint(list);
      expect(database.listener.isEmpty, isTrue);
    });
  });
}
