library sembast.compat.find_test;

// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';

import 'package:sembast/sembast.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('compat_find', () {
    Database db;

    Future _tearDown() async {
      if (db != null) {
        await db.close();
        db = null;
      }
    }

    Store store;
    Record record1, record2, record3;
    setUp(() async {
      db = await setupForTest(ctx, 'compat/find.db');
      store = db.mainStore;
      record1 = Record(store, "hi", 1);
      record2 = Record(store, "ho", 2);
      record3 = Record(store, "ha", 3);
      return db.putRecords([record1, record2, record3]);
    });

    tearDown(_tearDown);

    test('equal', () {
      Finder finder = Finder();
      finder.filter = Filter.equal(Field.value, "hi");
      return store.findRecords(finder).then((List<Record> records) {
        expect(records.length, 1);
        expect(records[0], record1);
      }).then((_) {
        Finder finder = Finder();
        finder.filter = Filter.equal(Field.value, "ho");
        return store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 1);
          expect(records[0], record2);
        });
      }).then((_) {
        Finder finder = Finder();
        finder.filter = Filter.equal(Field.value, "hum");
        return store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 0);
        });
      });
    });

    test('in_transaction', () {
      return db.transaction((Transaction txn) {
        var store = txn.mainStore;
        Finder finder = Finder();
        finder.filter = Filter.equal(Field.value, "hi");
        return store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 1);
          expect(records[0], record1);
        }).then((_) {
          Record record = Record(store.store, "he", 4);

          return txn.putRecord(record).then((_) {
            finder.filter = Filter.equal(Field.value, "he");
            return store.findRecords(finder).then((List<Record> records) {
              expect(records.length, 1);
              expect(records[0], record);
            });
          });
        }).then((_) {
          // delete ho
          return store.delete(2).then((_) {
            finder.filter = Filter.equal(Field.value, "ho");
            return store.findRecords(finder).then((List<Record> records) {
              expect(records.length, 0);
            });
          });
        });
      });
    });

    test('in_transaction no_filter', () {
      return db.transaction((txn) {
        StoreExecutor store = txn.mainStore;
        Finder finder = Finder();
        return store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 3);
          expect(records[0], record1);
        }).then((_) {
          Record record = Record(store.store, "he", 4);
          return txn.putRecord(record).then((_) {
            return store.findRecords(finder).then((List<Record> records) {
              expect(records.length, 4);
              // records are sorted by key by default
              expect(records[0], record1);
              expect(records[3], record);
              // expect(records[3], record);
              // expect(records[0], record1);
            });
          }).then((_) {
            return store.count().then((int count) {
              expect(count, 4);
            });
          });
        }).then((_) {
          // delete ho
          return store.delete(2).then((_) {
            return store.findRecords(finder).then((List<Record> records) {
              expect(records.length, 3);
            });
          });
        });
      });
    });

    test('delete_in_transaction', () {
      return db.transaction((txn) {
        var store = txn.mainStore;
        Finder finder = Finder();

        // delete ho
        return store.delete(2).then((_) {
          finder.filter = Filter.equal(Field.value, "ho");
          return store.findRecords(finder).then((List<Record> records) {
            expect(records.length, 0);
          });
        });
      });
    });

    test('less_greater', () {
      Finder finder = Finder();
      finder.filter = Filter.lessThan(Field.value, "hi");
      return store.findRecords(finder).then((List<Record> records) {
        expect(records.length, 1);
        expect(records[0], record3);
      }).then((_) {
        Finder finder = Finder();
        finder.filter = Filter.greaterThan(Field.value, "hi");
        return store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 1);
          expect(records[0], record2);
        });
      }).then((_) {
        Finder finder = Finder();
        finder.filter = Filter.greaterThan(Field.value, "hum");
        return store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 0);
        });
      }).then((_) {
        Finder finder = Finder();
        finder.filter = Filter.greaterThanOrEquals(Field.value, "ho");
        return store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 1);
          expect(records[0], record2);
        });
      }).then((_) {
        Finder finder = Finder();
        finder.filter = Filter.lessThanOrEquals(Field.value, "ha");
        return store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 1);
          expect(records[0], record3);
        });
      }).then((_) {
        Finder finder = Finder();
        finder.filter = Filter.inList(Field.value, ["ho"]);
        return store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 1);
          expect(records[0], record2);
        });
      });
    });

    test('matches', () async {
      Finder finder = Finder();
      finder.filter = Filter.matches(Field.value, "hi");
      var records = await store.findRecords(finder);
      expect(records.length, 1);
      expect(records[0], record1);
      // starts with
      records = await store
          .findRecords(Finder(filter: Filter.matches(Field.value, '^hi')));
      expect(records.length, 1);
      expect(records[0], record1);
      records = await store
          .findRecords(Finder(filter: Filter.matches(Field.value, '^h')));
      expect(records.length, 3);
      // ends with
      records = await store
          .findRecords(Finder(filter: Filter.matches(Field.value, r'hi$')));
      expect(records.length, 1);
      expect(records[0], record1);
      records = await store
          .findRecords(Finder(filter: Filter.matches(Field.value, r'a$')));
      expect(records.length, 1);
      expect(records[0], record3);

      // null value
      var record4 = Record(store, null, 4);
      await db.putRecord(record4);
      records = await store
          .findRecords(Finder(filter: Filter.matches(Field.value, '^hi')));
      expect(records.length, 1);

      // record 4 cannot be found using matches
      records = await store
          .findRecords(Finder(filter: Filter.matches(Field.value, "")));
      expect(records.length, 3);
      records =
          await store.findRecords(Finder(filter: Filter.isNull(Field.value)));
      expect(records.length, 1);
      expect(records.first.key, record4.key);
      records =
          await store.findRecords(Finder(filter: Filter.notNull(Field.value)));
      expect(records.length, 3);

      records = await store
          .findRecords(Finder(filter: Filter.matches(Field.key, '^hi')));
      expect(records, isEmpty);

      // empty value
      var record5 = Record(store, '', 5);
      await db.putRecord(record5);
      records = await store
          .findRecords(Finder(filter: Filter.matches(Field.value, '^hi')));
      expect(records.length, 1);

      // record 5 can be found using matches
      records = await store
          .findRecords(Finder(filter: Filter.matches(Field.value, "")));
      expect(records.length, 4);
      records = await store
          .findRecords(Finder(filter: Filter.equals(Field.value, "")));
      expect(records.length, 1);
      expect(records.first.key, record5.key);
      // matching empty string
      records = await store
          .findRecords(Finder(filter: Filter.matches(Field.value, r"^$")));
      expect(records.length, 1);
      expect(records.first.key, record5.key);
    });

    test('composite', () {
      Finder finder = Finder();
      finder.filter = Filter.and([
        Filter.lessThan(Field.value, "ho"),
        Filter.greaterThan(Field.value, "ha")
      ]);
      return store.findRecords(finder).then((List<Record> records) {
        expect(records.length, 1);
        expect(records[0], record1);
      }).then((_) {
        Finder finder = Finder();
        finder.filter = Filter.or([
          Filter.lessThan(Field.value, "hi"),
          Filter.greaterThan(Field.value, "hum")
        ]);
        return store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 1);
          expect(records[0], record3);
        });
      });
    });

    test('sort', () {
      Finder finder = Finder();
      finder.sortOrder = SortOrder(Field.value, true);
      return store.findRecords(finder).then((List<Record> records) {
        expect(records.length, 3);
        expect(records[0], record3);
        expect(records[1], record1);
        expect(records[2], record2);
      }).then((_) {
        finder.sortOrder = SortOrder(Field.value, false);
        return store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 3);
          expect(records[0], record2);
          expect(records[1], record1);
          expect(records[2], record3);
        });
      });
    });

    group('find_complex', () {
      Database db;
      Store store;
      Record record1, record2, record3;
      setUp(() async {
        db = await setupForTest(ctx, 'compat/find/find_complex.db');
        store = db.mainStore;
        record1 = Record(store, {"text": "hi", "value": 1}, 1);
        record2 = Record(store, {"text": "ho", "value": 2}, 2);
        record3 = Record(store, {"text": "ha", "value": 2}, 3);
        return db.putRecords([record1, record2, record3]);
      });

      tearDown(_tearDown);

      test('limit', () async {
        var finder = Finder(limit: 1);
        var records = await store.findRecords(finder);
        expect(records.length, 1);
        expect(records[0], record1);

        finder = Finder(limit: 4);
        records = await store.findRecords(finder);
        expect(records.length, 3);
        expect(records[0], record1);
        expect(records[2], record3);
      });

      test('offset', () async {
        var finder = Finder(offset: 1);
        var records = await store.findRecords(finder);
        expect(records.length, 2);
        expect(records[0], record2);
        expect(records[1], record3);

        finder = Finder(offset: 4);
        records = await store.findRecords(finder);
        expect(records.length, 0);
      });

      test('limit_offset', () async {
        var finder = Finder(limit: 1, offset: 1);
        var records = await store.findRecords(finder);
        expect(records.length, 1);
        expect(records[0], record2);

        finder = Finder(limit: 2, offset: 2);
        records = await store.findRecords(finder);
        expect(records.length, 1);
        expect(records[0], record3);
      });
    });

    group('find_null', () {
      test('first_last', () async {
        db = await setupForTest(ctx, 'compat/find/find_null.db');
        store = db.mainStore;
        record1 = Record(store, {"text": null}, 1);
        record2 = Record(store, {"text": "hi"}, 2);
        await db.putRecords([record1, record2]);

        Finder finder = Finder();
        finder.sortOrders = [SortOrder("text", true)];
        List<Record> records = await store.findRecords(finder);
        expect(records, [record1, record2]);

        finder = Finder();
        finder.sortOrders = [SortOrder("text", true, true)];
        records = await store.findRecords(finder);
        expect(records, [record2, record1]);

        // is null
        finder = Finder(filter: Filter.isNull("text"));
        records = await store.findRecords(finder);
        expect(records, [record1]);

        // not null
        finder = Finder(filter: Filter.notNull("text"));
        records = await store.findRecords(finder);
        expect(records, [record2]);
      });
    });

    void expectRecordKeys(List<Record> records, List<Record> expectedRecords) {
      var reason = '$records vs $expectedRecords';
      expect(records.length, expectedRecords.length, reason: reason);
      for (int i = 0; i < records.length; i++) {
        expect(records[i]?.key, expectedRecords[i]?.key,
            reason: 'index $i $reason');
      }
    }

    group('sub_field', () {
      Database db;
      Store store;
      Record record1, record2, record3;
      setUp(() async {
        db = await setupForTest(ctx, 'compat/find/sub_field.db');
        store = db.mainStore;
        record1 = Record(
            store,
            {
              "path": {"sub": 'a'}
            },
            1);
        record2 = Record(
            store,
            {
              "path": {"sub": 'c'}
            },
            2);
        record3 = Record(
            store,
            {
              "path": {"sub": 'b'}
            },
            3);
        // notice the order
        await db.putRecords([
          record1,
          record2,
          record3,
        ]);
      });

      tearDown(_tearDown);

      test('sort', () async {
        Finder finder = Finder();
        finder.sortOrders = [SortOrder("path.sub", true)];
        var records = await store.findRecords(finder);
        expectRecordKeys(records, [record1, record3, record2]);

        finder.filter = Filter.equals('path.sub', 'b');
        records = await store.findRecords(finder);
        expectRecordKeys(records, [record3]);

        // Add null
        var record4 = Record(store, {}, 4);
        record4 = await db.putRecord(record4);
        try {
          finder.sortOrders = [SortOrder("path.sub", true)];
          finder.filter = null;
          records = await store.findRecords(finder);
          expectRecordKeys(records, [record4, record1, record3, record2]);
          finder.sortOrders = [SortOrder("path.sub", true, true)];
          finder.filter = null;
          records = await store.findRecords(finder);
          expectRecordKeys(records, [record1, record3, record2, record4]);
        } finally {
          await db.deleteRecord(record4);
        }
      });

      /*
      void dumpRecords(List<Record> records) {
        for (var record in records) {
          print(record);
        }
      }
      */

      test('sort_descending', () async {
        Finder finder = Finder();
        // descending
        finder.sortOrders = [SortOrder("path.sub", false)];
        var records = await store.findRecords(finder);
        //dumpRecords(records);
        expectRecordKeys(records, [record2, record3, record1]);

        // Add null
        var record4 = Record(store, {}, 4);
        record4 = await db.putRecord(record4);
        try {
          finder.sortOrders = [SortOrder("path.sub", false)];
          records = await store.findRecords(finder);
          expectRecordKeys(records, [
            record2,
            record3,
            record1,
            record4,
          ]);
          finder.sortOrders = [SortOrder("path.sub", false, true)];
          records = await store.findRecords(finder);
          expectRecordKeys(records, [record4, record2, record3, record1]);
        } finally {
          await db.deleteRecord(record4);
        }
      });

      test('start', () async {
        Finder finder = Finder();
        finder.sortOrders = [SortOrder("path.sub", true)];

        finder.start = Boundary(values: ['b'], include: true);
        var records = await store.findRecords(finder);
        expectRecordKeys(records, [record3, record2]);

        finder.start = Boundary(values: ['a'], include: false);
        records = await store.findRecords(finder);
        expectRecordKeys(records, [record3, record2]);

        finder.start = Boundary(values: ['b'], include: false);
        records = await store.findRecords(finder);
        expectRecordKeys(records, [record2]);

        // descending
        finder.sortOrders = [SortOrder("path.sub", false)];
        finder.start = Boundary(values: ['b'], include: true);
        records = await store.findRecords(finder);
        expectRecordKeys(records, [record3, record1]);

        finder.start = Boundary(values: ['b'], include: false);
        records = await store.findRecords(finder);
        expectRecordKeys(records, [record1]);

        // Add null
        var record4 = Record(store, {}, 4);
        record4 = await db.putRecord(record4);
        try {
          finder.sortOrders = [SortOrder("path.sub", true)];
          finder.start = Boundary(values: ['b'], include: true);
          records = await store.findRecords(finder);
          expectRecordKeys(records, [record3, record2]);

          finder.sortOrders = [SortOrder("path.sub", true, true)];
          finder.start = Boundary(values: ['b'], include: true);
          records = await store.findRecords(finder);
          expectRecordKeys(records, [record3, record2, record4]);

          finder.sortOrders = [SortOrder("path.sub", false)];
          finder.start = Boundary(values: ['b'], include: true);
          records = await store.findRecords(finder);
          expectRecordKeys(records, [record3, record1, record4]);
        } finally {
          await db.deleteRecord(record4);
        }
      });

      test('end', () async {
        Finder finder = Finder();
        finder.sortOrders = [SortOrder("path.sub", true)];

        finder.end = Boundary(values: ['b'], include: true);
        var records = await store.findRecords(finder);
        expectRecordKeys(records, [record1, record3]);

        finder.end = Boundary(values: ['b'], include: false);
        records = await store.findRecords(finder);
        expectRecordKeys(records, [record1]);

        // descending
        finder.sortOrders = [SortOrder("path.sub", false)];
        finder.end = Boundary(values: ['b'], include: true);
        records = await store.findRecords(finder);
        expectRecordKeys(records, [record2, record3]);

        finder.end = Boundary(values: ['b'], include: false);
        records = await store.findRecords(finder);
        expectRecordKeys(records, [record2]);
      });

      test('start_end', () async {
        Finder finder = Finder();
        finder.sortOrders = [SortOrder("path.sub", true)];

        finder.start = Boundary(values: ['b'], include: true);
        finder.end = Boundary(values: ['b'], include: true);
        var records = await store.findRecords(finder);
        //print(records);
        expectRecordKeys(records, [record3]);

        finder.end = Boundary(values: ['b'], include: false);
        records = await store.findRecords(finder);
        expectRecordKeys(records, []);
      });
    });

    test('multi_sort_order', () async {
      db = await setupForTest(ctx, 'compat/find/multi_sort_order.db');

      // Store some objects
      dynamic key1, key2, key3, key4;
      Record record1, record2, record3, record4;
      await db.transaction((txn) async {
        key2 = await txn.put({'name': 'Lamp', 'price': 10});
        key3 = await txn.put({'name': 'Chair', 'price': 10});
        key4 = await txn.put({'name': 'Deco', 'price': 5});
        key1 = await txn.put({'name': 'Table', 'price': 35});
        record1 = await txn.getRecord(key1);
        record2 = await txn.getRecord(key2);
        record3 = await txn.getRecord(key3);
        record4 = await txn.getRecord(key4);
      });

      {
        // Sort by price and name
        var finder =
            Finder(sortOrders: [SortOrder('price'), SortOrder('name')]);
        var record = await db.findRecord(finder);
        // first is the Deco
        expect(record['name'], 'Deco');

        var records = await db.findRecords(finder);

        expectRecordKeys(records, [record4, record3, record2, record1]);
      }

      // Boundaries
      {
        // Look for object after Chair 10 (ordered by price then name) so
        // should the the Lamp
        var finder = Finder(
            sortOrders: [SortOrder('price'), SortOrder('name')],
            start: Boundary(values: [10, 'Chair']));
        var record = await db.findRecord(finder);
        expect(record['name'], 'Lamp');

        // You can also specify to look after a given record
        finder = Finder(
            sortOrders: [SortOrder('price'), SortOrder('name')],
            start: Boundary(record: record));
        record = await db.findRecord(finder);
        // After the lamp the more expensive one is the Table
        expect(record['name'], 'Table');

        // after the lamp by price is the chair
        // if not ordered by name
        finder = Finder(
            sortOrders: [SortOrder('price')], start: Boundary(record: record2));
        record = await db.findRecord(finder);
        // After the lamp the more expensive one is the Table
        expect(record['name'], 'Chair');
      }
    });
  });
}
