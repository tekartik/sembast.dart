library sembast.find_test;

// basically same as the io runner but with extra output
import 'dart:async';

import 'package:sembast/sembast.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('find', () {
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
      db = await setupForTest(ctx);
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
              // for now txn records are first
              expect(records[0], record);
              expect(records[3], record3);
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
        db = await setupForTest(ctx);
        store = db.mainStore;
        record1 = Record(store, {"text": "hi", "value": 1}, 1);
        record2 = Record(store, {"text": "ho", "value": 2}, 2);
        record3 = Record(store, {"text": "ha", "value": 2}, 3);
        return db.putRecords([record1, record2, record3]);
      });

      tearDown(_tearDown);

      test('sort', () {
        Finder finder = Finder();
        finder.sortOrders = [SortOrder("value", true), SortOrder("text", true)];
        return store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 3);
          expect(records[0], record1);
          expect(records[1], record3);
          expect(records[2], record2);
        }).then((_) {
          finder.sortOrders = [
            SortOrder("value", true),
            SortOrder("text", false)
          ];
          return store.findRecords(finder).then((List<Record> records) {
            expect(records.length, 3);
            expect(records[0], record1);
            expect(records[1], record2);
            expect(records[2], record3);
          });
        });
      });

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
        db = await setupForTest(ctx);
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
  });
}
