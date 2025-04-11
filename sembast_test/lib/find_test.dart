library;

import 'dart:async';

import 'package:sembast/timestamp.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  List<RecordRef> snapshotsRefs(List<RecordSnapshot> snapshots) =>
      snapshots.map((snapshot) => snapshot.ref).toList(growable: false);

  group('find', () {
    group('simple_value', () {
      late Database db;

      Future dbTearDown() async {
        await db.close();
      }

      var store = StoreRef<int, String>.main();
      final records = store.records([1, 2, 3]);
      // Convenient access for test
      var record1 = records[0];
      var record2 = records[1];
      var record3 = records[2];
      setUp(() async {
        db = await setupForTest(ctx, 'find/simple_value.db');
        return records.put(db, ['hi', 'ho', 'ha']);
      });

      tearDown(dbTearDown);

      test('equal', () async {
        var finder = Finder(filter: Filter.equals(Field.value, 'hi'));
        var snapshots = await store.find(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record1]);
        // test the content once, assume it is ok then...
        expect(snapshots[0].value, 'hi');

        finder = Finder(filter: Filter.equals(Field.value, 'ho'));
        snapshots = await store.find(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record2]);
        // test the keys and findFirst, assume it is ok then...
        expect((await store.findFirst(db, finder: finder))!.ref, record2);
        expect(await store.findKey(db, finder: finder), record2.key);
        expect(await store.findKeys(db, finder: finder), [record2.key]);

        finder = Finder(filter: Filter.equals(Field.value, 'hum'));
        snapshots = await store.find(db, finder: finder);
        expect(snapshots, isEmpty);
      });

      test('in_transaction', () async {
        await db.transaction((Transaction txn) async {
          final finder = Finder(filter: Filter.equals(Field.value, 'hi'));
          var snapshots = await store.find(txn, finder: finder);
          expect(snapshotsRefs(snapshots), [record1]);
          // test the content once, assume it is ok then...
          expect(snapshots[0].value, 'hi');

          var record4 = store.record(4);
          await record4.put(txn, 'he');

          finder.filter = Filter.equals(Field.value, 'he');
          // Present in transaction
          snapshots = await store.find(txn, finder: finder);
          expect(snapshotsRefs(snapshots), [record4]);
          snapshots = store.findSync(txn, finder: finder);
          expect(snapshotsRefs(snapshots), [record4]);
          // test the keys and findFirst, assume it is ok then...
          expect((await store.findFirst(txn, finder: finder))!.ref, record4);
          expect((store.findFirstSync(txn, finder: finder))!.ref, record4);
          expect(await store.findKey(txn, finder: finder), record4.key);
          expect(store.findKeySync(txn, finder: finder), record4.key);
          expect(await store.findKeys(txn, finder: finder), [record4.key]);
          expect(store.findKeysSync(txn, finder: finder), [record4.key]);

          // But not in db
          expect(await store.find(db, finder: finder), isEmpty);
          expect(await store.findFirst(db, finder: finder), isNull);
          expect(await store.findKey(db, finder: finder), isNull);
          expect(await store.findKeys(db, finder: finder), isEmpty);
          expect(store.findSync(db, finder: finder), isEmpty);
          expect(store.findFirstSync(db, finder: finder), isNull);
          expect(store.findKeySync(db, finder: finder), isNull);
          expect(store.findKeysSync(db, finder: finder), isEmpty);

          // delete ho
          await store.record(2).delete(txn);

          // Absent in transaction
          finder.filter = Filter.equals(Field.value, 'ho');
          snapshots = await store.find(txn, finder: finder);
          expect(snapshots, isEmpty);

          // Present in db
          snapshots = await store.find(db, finder: finder);
          expect(snapshotsRefs(snapshots), [record2]);
        });
      });

      test('in_transaction no_filter', () async {
        await db.transaction((txn) async {
          var snapshots = await store.find(db);
          expect(snapshotsRefs(snapshots), [record1, record2, record3]);

          var record4 = store.record(4);
          await record4.put(txn, 'he');

          // Present in db
          snapshots = await store.find(txn);
          // records are sorted by key by default
          expect(snapshotsRefs(snapshots), [
            record1,
            record2,
            record3,
            record4,
          ]);

          expect(await store.count(txn), 4);
          expect(await store.count(db), 3);

          // delete ho
          await record2.delete(txn);
          snapshots = await store.find(txn);
          expect(snapshotsRefs(snapshots), [record1, record3, record4]);

          expect(await store.count(txn), 3);
          expect(await store.count(db), 3);
        });
      });

      test('delete_in_transaction', () {
        return db.transaction((txn) async {
          // delete ho
          await record2.delete(txn);
          var filter = Filter.equals(Field.value, 'ho');
          expect(
            await store.find(txn, finder: Finder(filter: filter)),
            isEmpty,
          );
          expect(
            await store.find(db, finder: Finder(filter: filter)),
            isNotEmpty,
          );
        });
      });

      test('less_greater', () async {
        var finder = Finder(filter: Filter.lessThan(Field.value, 'hi'));
        var snapshots = await store.find(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record3]);
        finder = Finder(filter: Filter.greaterThan(Field.value, 'hi'));
        snapshots = await store.find(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record2]);

        finder = Finder(filter: Filter.greaterThan(Field.value, 'hum'));
        snapshots = await store.find(db, finder: finder);
        expect(snapshots.length, 0);

        finder = Finder(filter: Filter.greaterThanOrEquals(Field.value, 'ho'));
        snapshots = await store.find(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record2]);

        finder = Finder(filter: Filter.lessThanOrEquals(Field.value, 'ha'));
        snapshots = await store.find(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record3]);

        finder = Finder(filter: Filter.inList(Field.value, ['ho']));
        snapshots = await store.find(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record2]);
      });

      test('in_list', () async {
        var finder = Finder(filter: Filter.inList(Field.value, ['ho']));
        var snapshots = await store.find(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record2]);
      });

      test('matches', () async {
        var finder = Finder(filter: Filter.matches(Field.value, 'hi'));
        var snapshots = await store.find(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record1]);
        // starts with
        snapshots = await store.find(
          db,
          finder: Finder(filter: Filter.matches(Field.value, '^hi')),
        );
        expect(snapshotsRefs(snapshots), [record1]);
        snapshots = await store.find(
          db,
          finder: Finder(filter: Filter.matches(Field.value, '^h')),
        );
        expect(snapshotsRefs(snapshots), [record1, record2, record3]);
        // ends with
        snapshots = await store.find(
          db,
          finder: Finder(filter: Filter.matches(Field.value, r'hi$')),
        );
        expect(snapshotsRefs(snapshots), [record1]);
        snapshots = await store.find(
          db,
          finder: Finder(filter: Filter.matches(Field.value, r'a$')),
        );
        expect(snapshotsRefs(snapshots), [record3]);

        snapshots = await store.find(
          db,
          finder: Finder(filter: Filter.matches(Field.value, '')),
        );
        expect(snapshotsRefs(snapshots), [record1, record2, record3]);
        snapshots = await store.find(
          db,
          finder: Finder(filter: Filter.isNull(Field.value)),
        );
        expect(snapshotsRefs(snapshots), isEmpty);
        snapshots = await store.find(
          db,
          finder: Finder(filter: Filter.notNull(Field.value)),
        );
        expect(snapshotsRefs(snapshots), [record1, record2, record3]);

        snapshots = await store.find(
          db,
          finder: Finder(filter: Filter.matches(Field.key, '^hi')),
        );
        expect(snapshots, isEmpty);

        // empty value
        var record5 = store.record(5);
        await record5.put(db, '');
        snapshots = await store.find(
          db,
          finder: Finder(filter: Filter.matches(Field.value, '^hi')),
        );
        expect(snapshotsRefs(snapshots), [record1]);

        // record 5 can be found using matches
        snapshots = await store.find(
          db,
          finder: Finder(filter: Filter.matches(Field.value, '')),
        );
        expect(snapshotsRefs(snapshots), [record1, record2, record3, record5]);
        snapshots = await store.find(
          db,
          finder: Finder(filter: Filter.equals(Field.value, '')),
        );

        expect(snapshotsRefs(snapshots), [record5]);
        // matching empty string
        snapshots = await store.find(
          db,
          finder: Finder(filter: Filter.matches(Field.value, r'^$')),
        );
        expect(snapshotsRefs(snapshots), [record5]);
      });

      test('composite', () async {
        var finder = Finder(
          filter: Filter.and([
            Filter.lessThan(Field.value, 'ho'),
            Filter.greaterThan(Field.value, 'ha'),
          ]),
        );
        var snapshots = await store.find(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record1]);

        finder = Finder(
          filter: Filter.or([
            Filter.lessThan(Field.value, 'hi'),
            Filter.greaterThan(Field.value, 'hum'),
          ]),
        );
        snapshots = await store.find(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record3]);
      });

      test('sort', () async {
        var finder = Finder(sortOrders: [SortOrder(Field.value, true)]);
        var snapshots = await store.find(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record3, record1, record2]);

        finder.sortOrder = SortOrder(Field.value, false);
        snapshots = await store.find(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record2, record1, record3]);
      });
    });

    group('list_values', () {
      late Database db;

      var store = intMapStoreFactory.store();
      var records = store.records([1, 2, 3]);
      setUp(() async {
        db = await setupForTest(ctx, 'find/list_values.db');
        return records.put(db, [
          {
            'list1': [1, 4],
            'list2': ['t1', 't2'],
          },
          {
            'list1': [1, 4],
            'list2': ['t1', 't3'],
          },
          {
            'list1': [1, 'hi'],
            'list2': [1, 2],
          },
        ]);
      });
      tearDown(() async {
        await db.close();
      });
      test('contains', () async {
        var finder = Finder(filter: Filter.arrayContains('list1', 1));
        expect((await store.find(db, finder: finder)).keys, [1, 2, 3]);
        finder = Finder(filter: Filter.arrayContainsAny('list1', [1]));
        expect((await store.find(db, finder: finder)).keys, [1, 2, 3]);
        finder = Finder(filter: Filter.arrayContainsAll('list1', [1, 4]));
        expect((await store.find(db, finder: finder)).keys, [1, 2]);
        finder = Finder(filter: Filter.arrayContainsAll('list2', ['t1', 't3']));
        expect((await store.find(db, finder: finder)).keys, [2]);
      });
    });
    group('map_values', () {
      late Database db;

      var store = intMapStoreFactory.store();
      var records = store.records([1, 2, 3]);
      // Convenient access for test
      var record1 = records[0];
      var record2 = records[1];
      var record3 = records[2];
      setUp(() async {
        db = await setupForTest(ctx, 'find/map_values.db');
        return records.put(db, [
          {'text': 'hi', 'value': 1},
          {'text': 'ho', 'value': 2},
          {'text': 'ha', 'value': 2},
        ]);
      });

      tearDown(() async {
        await db.close();
      });

      test('limit', () async {
        var finder = Finder(limit: 1);
        var snapshots = await store.find(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record1]);

        finder = Finder(limit: 4);
        snapshots = await store.find(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record1, record2, record3]);
        snapshots = store.findSync(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record1, record2, record3]);
      });

      test('offset', () async {
        print(await store.find(db));
        var finder = Finder(offset: 1);
        var snapshots = await store.find(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record2, record3]);

        finder = Finder(offset: 4);
        snapshots = await store.find(db, finder: finder);
        expect(snapshots.length, 0);
        snapshots = store.findSync(db, finder: finder);
        expect(snapshots.length, 0);
      });

      test('limit_offset', () async {
        var finder = Finder(limit: 1, offset: 1);
        var snapshots = await store.find(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record2]);

        finder = Finder(limit: 2, offset: 2);
        snapshots = await store.find(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record3]);
      });

      test('null_first_last', () async {
        final db = await setupForTest(ctx, 'find/null_first_last.db');
        var store = intMapStoreFactory.store();

        record1 = store.record(1);
        record2 = store.record(2);

        await store.records([1, 2]).put(db, [
          {'text': null},
          {'text': 'hi'},
        ]);

        var finder = Finder(sortOrders: [SortOrder('text', true)]);
        var snapshots = await store.find(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record1, record2]);

        finder = Finder(sortOrders: [SortOrder('text', true, true)]);
        snapshots = await store.find(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record2, record1]);

        // is null
        finder = Finder(filter: Filter.isNull('text'));
        snapshots = await store.find(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record1]);

        // not null
        finder = Finder(filter: Filter.notNull('text'));
        snapshots = await store.find(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record2]);

        await db.close();
      });

      group('custom_type', () {
        late Database db;

        tearDown(() async {
          await db.close();
        });
        var store = intMapStoreFactory.store();
        var records = store.records([1, 2, 3, 4]);

        // Convenient access for test
        var record1 = records[0];
        var record2 = records[1];
        var record3 = records[2];
        var record4 = records[3];
        setUp(() async {
          db = await setupForTest(ctx, 'find/custom_type.db');
          return records.put(db, [
            {'timestamp': Timestamp(0, 3)},
            {'timestamp': Timestamp(0, 1)},
            {'timestamp': null},
            {'timestamp': Timestamp(0, 2)},
          ]);
        });

        test('sort', () async {
          var finder = Finder(sortOrders: [SortOrder('timestamp', true)]);
          var snapshots = await store.find(db, finder: finder);
          expect(snapshotsRefs(snapshots), [
            record3,
            record2,
            record4,
            record1,
          ]);

          // Custom sort order, reverting twice
          finder = Finder(
            sortOrders: [
              SortOrder<Timestamp>.custom(
                'timestamp',
                (timestamp1, timestamp2) => timestamp1.compareTo(timestamp2),
                true,
              ),
            ],
          );
          snapshots = await store.find(db, finder: finder);
          expect(snapshotsRefs(snapshots), [
            record3,
            record2,
            record4,
            record1,
          ]);

          // Custom sort order, reverting twice
          finder = Finder(
            sortOrders: [
              SortOrder<Timestamp>.custom(
                'timestamp',
                (timestamp1, timestamp2) => timestamp2.compareTo(timestamp1),
                false,
                true,
              ),
            ],
          );
          snapshots = await store.find(db, finder: finder);
          expect(snapshotsRefs(snapshots), [
            record3,
            record2,
            record4,
            record1,
          ]);
        });
      });
      group('sub_field', () {
        late Database db;

        tearDown(() async {
          await db.close();
        });
        var store = intMapStoreFactory.store();
        var records = store.records([1, 2, 3]);
        // Convenient access for test
        var record1 = records[0];
        var record2 = records[1];
        var record3 = records[2];
        setUp(() async {
          db = await setupForTest(ctx, 'find/sub_field.db');
          return records.put(db, [
            {
              'path': {'sub': 'a'},
            },
            {
              'path': {'sub': 'c'},
            },
            {
              'path': {'sub': 'b'},
            },
          ]);
        });

        test('equals', () async {
          var finder = Finder(filter: Filter.equals('path.sub', 'b'));
          var snapshots = await store.find(db, finder: finder);
          expect(snapshotsRefs(snapshots), [record3]);
        });

        test('sort', () async {
          var finder = Finder(sortOrders: [SortOrder('path.sub', true)]);
          var snapshots = await store.find(db, finder: finder);
          expect(snapshotsRefs(snapshots), [record1, record3, record2]);

          // Add null sub field
          var record4 = store.record(4);
          await record4.put(db, {});

          finder.sortOrders = [SortOrder('path.sub', true)];
          finder.filter = Filter.custom((record) => true);
          snapshots = await store.find(db, finder: finder);
          expect(snapshotsRefs(snapshots), [
            record4,
            record1,
            record3,
            record2,
          ]);
          finder.sortOrders = [SortOrder('path.sub', true, true)];
          snapshots = await (store.find(db, finder: finder));
          expect(snapshotsRefs(snapshots), [
            record1,
            record3,
            record2,
            record4,
          ]);
          snapshots = store.findSync(db, finder: finder);
          expect(snapshotsRefs(snapshots), [
            record1,
            record3,
            record2,
            record4,
          ]);
        });

        test('sort_descending', () async {
          // descending
          var finder = Finder(sortOrders: [SortOrder('path.sub', false)]);
          var snapshots = await store.find(db, finder: finder);
          //dumpRecords(records);
          expect(snapshotsRefs(snapshots), [record2, record3, record1]);

          // Add null
          var record4 = store.record(4);
          await record4.put(db, {});

          finder.sortOrders = [SortOrder('path.sub', false)];
          snapshots = await store.find(db, finder: finder);
          expect(snapshotsRefs(snapshots), [
            record2,
            record3,
            record1,
            record4,
          ]);
          finder.sortOrders = [SortOrder('path.sub', false, true)];
          snapshots = await (store.find(db, finder: finder));
          expect(snapshotsRefs(snapshots), [
            record4,
            record2,
            record3,
            record1,
          ]);
        });

        test('start', () async {
          final finder = Finder(sortOrders: [SortOrder('path.sub', true)]);

          finder.start = Boundary(values: ['b'], include: true);
          var snapshots = await store.find(db, finder: finder);
          expect(snapshotsRefs(snapshots), [record3, record2]);

          finder.start = Boundary(values: ['a'], include: false);
          snapshots = await store.find(db, finder: finder);
          expect(snapshotsRefs(snapshots), [record3, record2]);

          finder.start = Boundary(values: ['b'], include: false);
          snapshots = await store.find(db, finder: finder);
          expect(snapshotsRefs(snapshots), [record2]);

          // descending
          finder.sortOrders = [SortOrder('path.sub', false)];
          finder.start = Boundary(values: ['b'], include: true);
          snapshots = await store.find(db, finder: finder);
          expect(snapshotsRefs(snapshots), [record3, record1]);

          finder.start = Boundary(values: ['b'], include: false);
          snapshots = await store.find(db, finder: finder);
          expect(snapshotsRefs(snapshots), [record1]);

          // Add null
          var record4 = store.record(4);
          await record4.put(db, {});

          finder.sortOrders = [SortOrder('path.sub', true)];
          finder.start = Boundary(values: ['b'], include: true);
          snapshots = await store.find(db, finder: finder);
          expect(snapshotsRefs(snapshots), [record3, record2]);

          finder.sortOrders = [SortOrder('path.sub', true, true)];
          finder.start = Boundary(values: ['b'], include: true);
          snapshots = await (store.find(db, finder: finder));
          expect(snapshotsRefs(snapshots), [record3, record2, record4]);

          finder.sortOrders = [SortOrder('path.sub', false)];
          finder.start = Boundary(values: ['b'], include: true);
          snapshots = await (store.find(db, finder: finder));
          expect(snapshotsRefs(snapshots), [record3, record1, record4]);
        });

        test('end', () async {
          final finder = Finder();
          finder.sortOrders = [SortOrder('path.sub', true)];

          finder.end = Boundary(values: ['b'], include: true);
          var snapshots = await (store.find(db, finder: finder));
          expect(snapshotsRefs(snapshots), [record1, record3]);

          finder.end = Boundary(values: ['b'], include: false);
          snapshots = await (store.find(db, finder: finder));
          expect(snapshotsRefs(snapshots), [record1]);

          // descending
          finder.sortOrders = [SortOrder('path.sub', false)];
          finder.end = Boundary(values: ['b'], include: true);
          snapshots = await (store.find(db, finder: finder));
          expect(snapshotsRefs(snapshots), [record2, record3]);

          finder.end = Boundary(values: ['b'], include: false);
          snapshots = await (store.find(db, finder: finder));
          expect(snapshotsRefs(snapshots), [record2]);
        });

        test('start_end', () async {
          final finder = Finder();
          finder.sortOrders = [SortOrder('path.sub', true)];

          finder.start = Boundary(values: ['b'], include: true);
          finder.end = Boundary(values: ['b'], include: true);
          var snapshots = await (store.find(db, finder: finder));
          //print(records);
          expect(snapshotsRefs(snapshots), [record3]);

          finder.end = Boundary(values: ['b'], include: false);
          snapshots = await (store.find(db, finder: finder));
          expect(snapshotsRefs(snapshots), isEmpty);
        });
      });

      group('field_with_dot', () {
        late Database db;

        tearDown(() async {
          await db.close();
        });
        var store = intMapStoreFactory.store();
        var records = store.records([1, 2, 3]);
        // Convenient access for test
        var record1 = records[0];
        var record2 = records[1];
        var record3 = records[2];
        setUp(() async {
          db = await setupForTest(ctx, 'find/field_with_dot.db');
          return records.put(db, [
            {'foo.bar': 'a'},
            {'foo.bar': 'c'},
            {'foo.bar': 'b'},
          ]);
        });

        test('sort', () async {
          var finder = Finder(
            sortOrders: [SortOrder(FieldKey.escape('foo.bar'), true)],
          );
          var snapshots = await (store.find(db, finder: finder));
          expect(snapshotsRefs(snapshots), [record1, record3, record2]);

          finder.filter = Filter.equals(FieldKey.escape('foo.bar'), 'b');
          snapshots = await (store.find(db, finder: finder));
          expect(snapshotsRefs(snapshots), [record3]);
        });

        test('start', () async {
          final finder = Finder(
            sortOrders: [SortOrder(FieldKey.escape('foo.bar'), true)],
          );

          finder.start = Boundary(values: ['b'], include: true);
          var snapshots = await (store.find(db, finder: finder));
          expect(snapshotsRefs(snapshots), [record3, record2]);
        });
      });

      test('multi_sort_order', () async {
        final db = await setupForTest(ctx, 'find/multi_sort_order.db');

        var store = intMapStoreFactory.store();
        // var _records = store.records([1, 2, 3, 4]);
        // Convenient access for test
        var record1 = store.record(1);
        var record2 = store.record(2);
        var record3 = store.record(3);
        var record4 = store.record(4);

        // Insert in a different order
        await store.records([2, 3, 4, 1]).put(db, [
          {'name': 'Lamp', 'price': 10},
          {'name': 'Chair', 'price': 10},
          {'name': 'Deco', 'price': 5},
          {'name': 'Table', 'price': 35},
        ]);

        var snapshot2 = await (record2.getSnapshot(db));

        {
          // Sort by price and name
          var finder = Finder(
            sortOrders: [SortOrder('price'), SortOrder('name')],
          );
          var snapshot = await (store.findFirst(db, finder: finder));
          // first is the Deco
          expect(snapshot!['name'], 'Deco');
          expect(await store.findKey(db, finder: finder), record4.key);

          var snapshots = await (store.find(db, finder: finder));

          expect(snapshotsRefs(snapshots), [
            record4,
            record3,
            record2,
            record1,
          ]);
        }

        // Boundaries
        {
          // Look for object after Chair 10 (ordered by price then name) so
          // should the the Lamp
          var finder = Finder(
            sortOrders: [SortOrder('price'), SortOrder('name')],
            start: Boundary(values: [10, 'Chair']),
          );
          var snapshot = await store.findFirst(db, finder: finder);
          expect(snapshot!['name'], 'Lamp');

          // You can also specify to look after a given record
          finder = Finder(
            sortOrders: [SortOrder('price'), SortOrder('name')],
            start: Boundary(record: snapshot),
          );
          snapshot = await store.findFirst(db, finder: finder);
          // After the lamp the more expensive one is the Table
          expect(snapshot!['name'], 'Table');

          // Next is null
          finder = Finder(
            sortOrders: [SortOrder('price'), SortOrder('name')],
            start: Boundary(record: snapshot),
          );
          snapshot = await (store.findFirst(db, finder: finder));
          // After the Table, no more result
          expect(snapshot, isNull);

          // after the lamp by price is the chair
          // if not ordered by name
          finder = Finder(
            sortOrders: [SortOrder('price')],
            start: Boundary(record: snapshot2),
          );
          snapshot = (await store.findFirst(db, finder: finder))!;
          // After the lamp the more expensive one (actually same price
          // but next id) is the Chair
          expect(snapshot['name'], 'Chair');
        }

        await db.close();
      });

      test('multi_sort_order_with_key', () async {
        final db = await setupForTest(ctx, 'find/multi_sort_order_with_key.db');

        var store = intMapStoreFactory.store();

        // Insert in a different order
        await store.records([2, 3, 4, 1]).put(db, [
          {'name': 'Lamp', 'price': 10},
          {'name': 'Chair', 'price': 10},
          {'name': 'Deco', 'price': 5},
          {'name': 'Table', 'price': 35},
        ]);

        {
          Finder finder;
          RecordSnapshot? snapshot;

          // Next is null
          finder = Finder(
            sortOrders: [SortOrder('price'), SortOrder(Field.key)],
            start: Boundary(values: [35, 1]),
          );
          snapshot = await store.findFirst(db, finder: finder);
          // After the lamp the more expensive one is the Table
          expect(snapshot, isNull);

          // Look for object after Chair 10 (ordered by price then name) so
          // should the the Lamp
          finder = Finder(
            sortOrders: [SortOrder('price'), SortOrder(Field.key)],
            start: Boundary(values: [10, 2]),
          );
          snapshot = await store.findFirst(db, finder: finder);
          expect(snapshot!['name'], 'Chair');

          // You can also specify to look after a given record
          finder = Finder(
            sortOrders: [SortOrder('price'), SortOrder(Field.key)],
            start: Boundary(record: snapshot),
          );
          snapshot = await (store.findFirst(db, finder: finder));
          // After the lamp the more expensive one is the Table
          expect(snapshot!['name'], 'Table');

          // Next is null
          finder = Finder(
            sortOrders: [SortOrder('price'), SortOrder(Field.key)],
            start: Boundary(record: snapshot),
          );
          snapshot = await (store.findFirst(db, finder: finder));
          // After the lamp the more expensive one is the Table
          expect(snapshot, isNull);
        }

        await db.close();
      });
    });
    group('sub_list_field', () {
      late Database db;

      tearDown(() async {
        await db.close();
      });
      var store = intMapStoreFactory.store();
      var records = store.records([1, 2, 3, 4]);
      // Convenient access for test
      var record1 = records[0];
      var record2 = records[1];
      var record3 = records[2];
      var record4 = records[3];
      setUp(() async {
        db = await setupForTest(ctx, 'find/sub_map_field.db');
        return records.put(db, [
          {
            'path': [
              {'sub': 'a'},
            ],
          },
          {
            'path': [
              {'sub': 'c'},
            ],
          },
          {
            'path': [
              {'sub': 'b'},
            ],
          },
          {'path': []},
        ]);
      });

      test('equals', () async {
        var finder = Finder(filter: Filter.equals('path.@.sub', 'b'));
        var snapshots = await store.find(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record3]);
      });
      test('sort', () async {
        var finder = Finder(sortOrders: [SortOrder('path.0.sub')]);
        var snapshots = await store.find(db, finder: finder);
        expect(snapshotsRefs(snapshots), [record1, record3, record2, record4]);
      });
    });
  });
}
