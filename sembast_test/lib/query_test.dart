library sembast_test.query_test;

// basically same as the io runner but with extra output

import 'dart:convert';

import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/json_encodable_codec.dart' show JsonEncodableCodec;
import 'package:sembast/src/type_adapter_impl.dart' show sembastDateTimeAdapter;
import 'package:sembast/timestamp.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('query', () {
    late Database db;

    setUp(() async {
      db = await setupForTest(ctx, 'query.db');
    });

    tearDown(() {
      return db.close();
    });

    Future expectQueryAndFirstSnapshotKeys(
        Finder? finder, List<int> keys) async {
      var store = StoreRef<int, Object?>.main();
      var results = await store.query(finder: finder).onSnapshots(db).first;
      expect(results.map((e) => e.key), keys);
      results = await store.query(finder: finder).getSnapshots(db);
      expect(results.map((e) => e.key), keys);
      results = await store.find(db, finder: finder);
      expect(results.map((e) => e.key), keys);
      var result = await store.findFirst(db, finder: finder);
      var queryResult = await store.query(finder: finder).getSnapshot(db);
      expect(result?.key, queryResult?.key);
      if (keys.isEmpty) {
        expect(result, isNull);
      } else {
        expect(result!.key, keys.first);
      }
    }

    test('put/query timing', () async {
      // No random timing
      setDatabaseCooperator(db, null);

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
      expect((await query.getSnapshot(db))!.key, 1);
      await expectQueryAndFirstSnapshotKeys(null, [1, 2]);
      var finder = Finder(filter: Filter.equals(Field.value, 'test2'));
      query = store.query(finder: finder);
      await expectQueryAndFirstSnapshotKeys(finder, [2]);
      expect(
          (await query.getSnapshots(db)).map((snapshot) => snapshot.key), [2]);
      expect((await query.getSnapshot(db))!.key, 2);
      finder = Finder(filter: Filter.equals(Field.value, 'test3'));
      query = store.query(finder: finder);
      await expectQueryAndFirstSnapshotKeys(finder, []);
      expect(
          (await query.getSnapshots(db)).map((snapshot) => snapshot.key), []);
      expect((await query.getSnapshot(db)), isNull);
    });

    test('store put/onSnapshots timing', () async {
      // No random timing
      setDatabaseCooperator(db, null);

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

      try {
        expect((await future2), hasLength(0));
      } catch (_) {
        expect((await future2).first.value, 'test');
        expect((await future2), hasLength(1));
      }
      //
      try {
        expect((await future3), isEmpty);
      } catch (_) {
        expect((await future3).first.value, 'test2');
        expect((await future3), hasLength(1));
      }
      expect(await future4, isEmpty);
    });

    test('record put/onSnapshot timing', () async {
      // No random timing
      setDatabaseCooperator(db, null);

      var record = StoreRef<int, String>.main().record(1);
      var future1 = record.onSnapshot(db).first;
      await record.put(db, 'test');
      var future2 = record.onSnapshot(db).first;
      await record.put(db, 'test2');
      var future3 = record.onSnapshot(db).first;
      await future3;
      await record.delete(db);
      var future4 = record.onSnapshot(db).first;
      expect(await future1, isNull);

      try {
        expect((await future2)!.value, 'test2');
      } catch (e) {
        expect((await future2)!.value, 'test');
      }
      /*
      expect((await future2).first.value, 'test');
      */
      expect((await future3)!.value, 'test2');
      expect(await future4, isNull);
    });

    test('onSnapshots', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);
      var index = 0;
      var completer = Completer();

      // When starting listening the record does not exists yet
      var query = store.query();
      var sub = query.onSnapshots(db).listen((snapshots) {
        // devPrint('$index $snapshots');
        var first = snapshots.isNotEmpty ? snapshots.first : null;
        final key = first?.key;
        final value = first?.value;

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

    test('StoreRef.onSnapshot', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);
      var index = 0;
      var completer = Completer();

      // When starting listening the record does not exists yet
      var query = store.query();
      var sub = query.onSnapshot(db).listen((snapshot) {
        // devPrint('$index $snapshots');
        var first = snapshot;
        final key = first?.key;
        final value = first?.value;

        if (index == 0) {
          expect(snapshot, isNull);
        } else if (index == 1) {
          expect(key, 1);
          expect(value, 'test');
        } else if (index == 2) {
          expect(key, 1);
          expect(value, 'test');
        } else if (index == 3) {
          expect(key, 1);
          expect(value, 'test2');
        } else if (index == 4) {
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

    test('onSnapshotNonNull', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);
      var future =
          record.onSnapshot(db).where((snapshot) => snapshot != null).first;
      // ignore: unawaited_futures
      record.put(db, 'test1');
      await future;
    });

    test('onSnapshotsNonNull', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);
      var future = store
          .query()
          .onSnapshots(db)
          .where((snapshots) => snapshots.isNotEmpty)
          .first;
      // ignore: unawaited_futures
      record.put(db, 'test1');
      await future;
    });

    test('onSnapshotNull', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);
      await record.put(db, 'test1');
      var future =
          record.onSnapshot(db).where(((snapshot) => snapshot == null)).first;
      // ignore: unawaited_futures
      record.delete(db);
      await future;
    });

    test('onSnapshotsNull', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);
      await record.put(db, 'test1');
      var future = store
          .query()
          .onSnapshots(db)
          .where((snapshots) => snapshots.isEmpty)
          .first;
      // ignore: unawaited_futures
      record.delete(db);
      await future;
    });

    test('onSnapshotsWithFinder', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);
      var index = 0;
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
        final key = first?.key;
        final value = first?.value;

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
      // with offset
      expect(
          (await store.query(finder: Finder(offset: 1)).onSnapshots(db).first),
          isEmpty);
    });

    test('onSnapshotsBeforeCreationAndUpdate', () async {
      // No random timing
      setDatabaseCooperator(db, null);

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
      // No random timing
      setDatabaseCooperator(db, null);
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
      await future4;
      await record1.put(db, 'ab');
      var future5 = query.onSnapshots(db).first;

      expect(await future1, isEmpty);

      expect((await future2).length, 1);
      expect((await future2).first.value, 'abcd');

      /*
        expect((await future3).length, 2);
        expect((await future3).first.value, 'abcd');
        expect((await future3)[1].value, 'abd');
       */
      expect((await future3).length, 1);
      expect((await future3).first.value, 'abcd');

      expect((await future4).length, 2);
      expect((await future4).first.value, 'abcd');
      expect((await future4)[1].value, 'abd');

      //expect((await future4).first.value, 'abcd');
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

    test('onSnapshots order custom type records', () async {
      await db.close();
      await ctx.factory.deleteDatabase(db.path);
      var codec = SembastCodec(
          signature: 'datetime',
          codec: json,
          jsonEncodableCodec:
              JsonEncodableCodec(adapters: [sembastDateTimeAdapter]));
      db = await ctx.factory.openDatabase(db.path, codec: codec);
      var store = intMapStoreFactory.store();
      var record1 = store.record(1);
      var record2 = store.record(2);
      var finder = Finder(sortOrders: [SortOrder('dateTime')]);
      var future1 = store.query(finder: finder).onSnapshots(db).first;
      await db.transaction((txn) async {
        await record1.put(txn, <String, Object?>{'dateTime': DateTime(2020)});
        await record2.put(txn, <String, Object?>{'dateTime': DateTime(2019)});
      });
      var future2 = store.query(finder: finder).onSnapshots(db).first;
      expect(await future1, isEmpty);
      expect((await future2)[0].key, record2.key);
      expect((await future2)[1].key, record1.key);
    });

    test('onSnapshots 2 records sort order', () async {
      var store = StoreRef<int, String>.main();
      var record1 = store.record(1);
      var record2 = store.record(2);
      var finder = Finder(sortOrders: [SortOrder(Field.value)]);
      var results1 = <List<RecordSnapshot>>[];
      var subscription =
          store.query(finder: finder).onSnapshots(db).listen((event) {
        results1.add(event);
      });
      await db.transaction((txn) async {
        await record1.put(txn, 'test2');
        await record2.put(txn, 'test1');
      });
      var future2 = store.query(finder: finder).onSnapshots(db).first;

      expect((await future2)[0].key, record2.key);
      expect((await future2)[1].key, record1.key);
      await expectQueryAndFirstSnapshotKeys(finder, [2, 1]);
      expect(results1.map((e) => e.map((e) => e.key)), [
        [],
        [2, 1]
      ]);
      await subscription.cancel();
    });

    test('onSnapshots 2 records sort order start', () async {
      var store = StoreRef<int, String>.main();
      var record1 = store.record(1);
      var record2 = store.record(2);
      var finder = Finder(
          sortOrders: [SortOrder(Field.value)],
          start: Boundary(include: true, values: ['test2']));
      var results1 = <List<RecordSnapshot>>[];
      var subscription =
          store.query(finder: finder).onSnapshots(db).listen((event) {
        results1.add(event);
      });
      // var future1 = store.query(finder: finder).onSnapshots(db).first;
      await db.transaction((txn) async {
        await record1.put(txn, 'test1');
        await record2.put(txn, 'test2');
      });
      await expectQueryAndFirstSnapshotKeys(finder, [2]);
      await record1.put(db, 'test3');
      await expectQueryAndFirstSnapshotKeys(finder, [2, 1]);

      await record2.put(db, 'test0');
      await expectQueryAndFirstSnapshotKeys(finder, [1]);
      expect(results1.map((e) => e.map((e) => e.key).toList()).toList(), [
        [],
        [2],
        [2, 1],
        [1]
      ]);

      await subscription.cancel();
    });

    test('onSnapshots 2 records sort order end', () async {
      var store = StoreRef<int, String>.main();
      var record1 = store.record(1);
      var record2 = store.record(2);
      var finder = Finder(
          sortOrders: [SortOrder(Field.value)],
          end: Boundary(include: false, values: ['test2']));
      var results1 = <List<RecordSnapshot>>[];
      var subscription =
          store.query(finder: finder).onSnapshots(db).listen((event) {
        results1.add(event);
      });
      await db.transaction((txn) async {
        await record1.put(txn, 'test2');
        await record2.put(txn, 'test1');
      });
      await expectQueryAndFirstSnapshotKeys(finder, [2]);
      expect(results1.map((e) => e.map((e) => e.key).toList()).toList(), [
        [],
        [2]
      ]);
      await subscription.cancel();
    });

    test('onSnapshots 2 records sort order different types', () async {
      List<RecordSnapshot> results;
      var store = StoreRef<int, Object?>.main();
      var record1 = store.record(1);
      var record2 = store.record(2);
      var finder = Finder(sortOrders: [SortOrder(Field.value)]);
      var results1 = <List<RecordSnapshot>>[];
      var subscription =
          store.query(finder: finder).onSnapshots(db).listen((event) {
        results1.add(event);
      });
      await db.transaction((txn) async {
        await record1.put(txn, 'test1');
        await record2.put(txn, 2);
      });
      results = await store.query(finder: finder).onSnapshots(db).first;
      expect(results.map((e) => e.key), [2, 1]);
      expect(results1.map((e) => e.map((e) => e.key).toList()).toList(), [
        [],
        [2, 1]
      ]);

      await subscription.cancel();
    });

    test('onSnapshots 2 records offset', () async {
      List<RecordSnapshot> results;
      var store = StoreRef<int, String>.main();
      var record1 = store.record(1);
      var record2 = store.record(2);
      var finder = Finder(offset: 1);
      var results1 = <List<RecordSnapshot>>[];
      var subscription =
          store.query(finder: finder).onSnapshots(db).listen((event) {
        results1.add(event);
      });
      await db.transaction((txn) async {
        await record1.put(txn, 'test1');
        await record2.put(txn, 'test2');
      });
      results = await store.query(finder: finder).onSnapshots(db).first;
      expect(results.map((e) => e.key), [2]);
      expect(results1.map((e) => e.map((e) => e.key).toList()).toList(), [
        [],
        [2]
      ]);

      await subscription.cancel();
    });
    test('onSnapshots 2 records limit', () async {
      List<RecordSnapshot> results;
      var store = StoreRef<int, String>.main();
      var record1 = store.record(1);
      var record2 = store.record(2);
      var finder = Finder(limit: 1);
      var results1 = <List<RecordSnapshot>>[];
      var subscription =
          store.query(finder: finder).onSnapshots(db).listen((event) {
        results1.add(event);
      });
      await db.transaction((txn) async {
        await record1.put(txn, 'test1');
        await record2.put(txn, 'test2');
      });
      results = await store.query(finder: finder).onSnapshots(db).first;
      expect(results.map((e) => e.key), [1]);
      await record1.delete(db);
      results = await store.query(finder: finder).onSnapshots(db).first;
      expect(results.map((e) => e.key), [2]);

      await record1.put(db, 'test1');
      results = await store.query(finder: finder).onSnapshots(db).first;
      expect(results.map((e) => e.key), [1]);
      expect(results1.map((e) => e.map((e) => e.key).toList()).toList(), [
        [],
        [1],
        [2],
        [1],
      ]);

      await subscription.cancel();
    });

    test('onSnapshots all ascending', () async {
      var store = intMapStoreFactory.store();
      var record1 = store.record(1);
      var record2 = store.record(2);
      var record3 = store.record(3);
      var record4 = store.record(4);
      var finder = Finder(
          sortOrders: [SortOrder('dateTime', true)],
          end: Boundary(
              values: [Timestamp.fromDateTime(DateTime.utc(2020))],
              include: false),
          start: Boundary(
              values: [Timestamp.fromDateTime(DateTime.utc(2010))],
              include: true),
          limit: 2,
          offset: 1,
          filter: Filter.custom((record) =>
              (record['dateTime'] as Timestamp).toDateTime(isUtc: true).month ==
              DateTime.january));
      var results1 = <List<RecordSnapshot>>[];
      var subscription =
          store.query(finder: finder).onSnapshots(db).listen((event) {
        results1.add(event);
      });
      await db.transaction((txn) async {
        await record1.put(txn, <String, Object?>{
          'dateTime': Timestamp.fromDateTime(DateTime.utc(2020))
        });
        await record2.put(txn, <String, Object?>{
          'dateTime': Timestamp.fromDateTime(DateTime.utc(2018))
        });
        await record3.put(txn, <String, Object?>{
          'dateTime': Timestamp.fromDateTime(DateTime.utc(2016))
        });
        await record4.put(txn, <String, Object?>{
          'dateTime': Timestamp.fromDateTime(DateTime.utc(2009))
        });
      });
      await expectQueryAndFirstSnapshotKeys(finder, [2]);

      await db.transaction((txn) async {
        await record1.put(txn, <String, Object?>{
          'dateTime': Timestamp.fromDateTime(DateTime.utc(2010))
        });
        await record2.put(txn, <String, Object?>{
          'dateTime': Timestamp.fromDateTime(DateTime.utc(2018, 2))
        });
        await record4.put(txn, <String, Object?>{
          'dateTime': Timestamp.fromDateTime(DateTime.utc(2014))
        });
      });
      await expectQueryAndFirstSnapshotKeys(finder, [4, 3]);
      await record2
          .put(db, {'dateTime': Timestamp.fromDateTime(DateTime.utc(2017))});
      await expectQueryAndFirstSnapshotKeys(finder, [4, 3]);

      await db.transaction((txn) async {
        await record1.delete(txn);
        await record3.delete(txn);
      });
      await expectQueryAndFirstSnapshotKeys(finder, [2]);
      expect(results1.map((e) => e.map((e) => e.key).toList()).toList(), [
        [],
        [2],
        [4, 3],
        [4, 3],
        [2]
      ]);
      await subscription.cancel();
    });

    test('onSnapshots all reverse', () async {
      var store = intMapStoreFactory.store();
      var record1 = store.record(1);
      var record2 = store.record(2);
      var record3 = store.record(3);
      var record4 = store.record(4);
      var finder = Finder(
          sortOrders: [SortOrder('dateTime', false)],
          start: Boundary(
              values: [Timestamp.fromDateTime(DateTime.utc(2020))],
              include: false),
          end: Boundary(
              values: [Timestamp.fromDateTime(DateTime.utc(2010))],
              include: true),
          limit: 2,
          offset: 1,
          filter: Filter.custom((record) =>
              (record['dateTime'] as Timestamp).toDateTime(isUtc: true).month ==
              DateTime.january));
      var results1 = <List<RecordSnapshot>>[];
      var subscription =
          store.query(finder: finder).onSnapshots(db).listen((event) {
        results1.add(event);
      });
      await db.transaction((txn) async {
        await record1.put(txn, <String, Object?>{
          'dateTime': Timestamp.fromDateTime(DateTime.utc(2020))
        });
        await record2.put(txn, <String, Object?>{
          'dateTime': Timestamp.fromDateTime(DateTime.utc(2018))
        });
        await record3.put(txn, <String, Object?>{
          'dateTime': Timestamp.fromDateTime(DateTime.utc(2016))
        });
        await record4.put(txn, <String, Object?>{
          'dateTime': Timestamp.fromDateTime(DateTime.utc(2009))
        });
      });
      await expectQueryAndFirstSnapshotKeys(finder, [3]);

      await db.transaction((txn) async {
        await record1.put(txn, <String, Object?>{
          'dateTime': Timestamp.fromDateTime(DateTime.utc(2010))
        });
        await record2.put(txn, <String, Object?>{
          'dateTime': Timestamp.fromDateTime(DateTime.utc(2018, 2))
        });
        await record4.put(txn, <String, Object?>{
          'dateTime': Timestamp.fromDateTime(DateTime.utc(2014))
        });
      });
      await expectQueryAndFirstSnapshotKeys(finder, [4, 1]);
      await record2
          .put(db, {'dateTime': Timestamp.fromDateTime(DateTime.utc(2017))});
      await expectQueryAndFirstSnapshotKeys(finder, [3, 4]);

      await db.transaction((txn) async {
        await record1.delete(txn);
        await record3.delete(txn);
      });
      await expectQueryAndFirstSnapshotKeys(finder, [4]);
      expect(results1.map((e) => e.map((e) => e.key).toList()).toList(), [
        [],
        [3],
        [4, 1],
        [3, 4],
        [4],
      ]);
      await subscription.cancel();
    });
  });
}
