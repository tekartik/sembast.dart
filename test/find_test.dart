library sembast.find_test;

// basically same as the io runner but with extra output
import 'package:sembast/sembast.dart';
import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('find', () {
    Database db;

    _tearDown() {
      if (db != null) {
        db.close();
        db = null;
      }
    }
    Store store;
    Record record1, record2, record3;
    setUp(() async {
      db = await setupForTest(ctx);
      store = db.mainStore;
      record1 = new Record(store, "hi", 1);
      record2 = new Record(store, "ho", 2);
      record3 = new Record(store, "ha", 3);
      return db.putRecords([record1, record2, record3]);
    });

    tearDown(_tearDown);

    test('equal', () {
      Finder finder = new Finder();
      finder.filter = new Filter.equal(Field.VALUE, "hi");
      return store.findRecords(finder).then((List<Record> records) {
        expect(records.length, 1);
        expect(records[0], record1);
      }).then((_) {
        Finder finder = new Finder();
        finder.filter = new Filter.equal(Field.VALUE, "ho");
        return store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 1);
          expect(records[0], record2);
        });
      }).then((_) {
        Finder finder = new Finder();
        finder.filter = new Filter.equal(Field.VALUE, "hum");
        return store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 0);
        });
      });
    });

    test('in_transaction', () {
      return db.inTransaction(() {
        Finder finder = new Finder();
        finder.filter = new Filter.equal(Field.VALUE, "hi");
        return store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 1);
          expect(records[0], record1);
        }).then((_) {
          Record record = new Record(store, "he", 4);

          return db.putRecord(record).then((_) {
            finder.filter = new Filter.equal(Field.VALUE, "he");
            return store.findRecords(finder).then((List<Record> records) {
              expect(records.length, 1);
              expect(records[0], record);
            });
          });
        }).then((_) {
          // delete ho
          return store.delete(2).then((_) {
            finder.filter = new Filter.equal(Field.VALUE, "ho");
            return store.findRecords(finder).then((List<Record> records) {
              expect(records.length, 0);
            });
          });
        });
      });
    });

    test('in_transaction no_filter', () {
      return db.inTransaction(() {
        Finder finder = new Finder();
        return store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 3);
          expect(records[0], record1);
        }).then((_) {
          Record record = new Record(store, "he", 4);
          return db.putRecord(record).then((_) {
            return store.findRecords(finder).then((List<Record> records) {
              expect(records.length, 4);
              // for now txn records are first
              expect(records[0], record);
              expect(records[3], record3);
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
      return db.inTransaction(() {
        Finder finder = new Finder();

        // delete ho
        return store.delete(2).then((_) {
          finder.filter = new Filter.equal(Field.VALUE, "ho");
          return store.findRecords(finder).then((List<Record> records) {
            expect(records.length, 0);
          });
        });
      });
    });

    test('less_greater', () {
      Finder finder = new Finder();
      finder.filter = new Filter.lessThan(Field.VALUE, "hi");
      return store.findRecords(finder).then((List<Record> records) {
        expect(records.length, 1);
        expect(records[0], record3);
      }).then((_) {
        Finder finder = new Finder();
        finder.filter = new Filter.greaterThan(Field.VALUE, "hi");
        return store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 1);
          expect(records[0], record2);
        });
      }).then((_) {
        Finder finder = new Finder();
        finder.filter = new Filter.greaterThan(Field.VALUE, "hum");
        return store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 0);
        });
      }).then((_) {
        Finder finder = new Finder();
        finder.filter = new Filter.greaterThanOrEquals(Field.VALUE, "ho");
        return store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 1);
          expect(records[0], record2);
        });
      }).then((_) {
        Finder finder = new Finder();
        finder.filter = new Filter.lessThanOrEquals(Field.VALUE, "ha");
        return store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 1);
          expect(records[0], record3);
        });
      }).then((_) {
        Finder finder = new Finder();
        finder.filter = new Filter.inList(Field.VALUE, ["ho"]);
        return store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 1);
          expect(records[0], record2);
        });
      });
    });

    test('composite', () {
      Finder finder = new Finder();
      finder.filter = new Filter.and([
        new Filter.lessThan(Field.VALUE, "ho"),
        new Filter.greaterThan(Field.VALUE, "ha")
      ]);
      return store.findRecords(finder).then((List<Record> records) {
        expect(records.length, 1);
        expect(records[0], record1);
      }).then((_) {
        Finder finder = new Finder();
        finder.filter = new Filter.or([
          new Filter.lessThan(Field.VALUE, "hi"),
          new Filter.greaterThan(Field.VALUE, "hum")
        ]);
        return store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 1);
          expect(records[0], record3);
        });
      });
    });

    test('sort', () {
      Finder finder = new Finder();
      finder.sortOrder = new SortOrder(Field.VALUE, true);
      return store.findRecords(finder).then((List<Record> records) {
        expect(records.length, 3);
        expect(records[0], record3);
        expect(records[1], record1);
        expect(records[2], record2);
      }).then((_) {
        finder.sortOrder = new SortOrder(Field.VALUE, false);
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
        record1 = new Record(store, {"text": "hi", "value": 1}, 1);
        record2 = new Record(store, {"text": "ho", "value": 2}, 2);
        record3 = new Record(store, {"text": "ha", "value": 2}, 3);
        return db.putRecords([record1, record2, record3]);
      });

      tearDown(_tearDown);

      test('sort', () {
        Finder finder = new Finder();
        finder.sortOrders = [
          new SortOrder("value", true),
          new SortOrder("text", true)
        ];
        return store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 3);
          expect(records[0], record1);
          expect(records[1], record3);
          expect(records[2], record2);
        }).then((_) {
          finder.sortOrders = [
            new SortOrder("value", true),
            new SortOrder("text", false)
          ];
          return store.findRecords(finder).then((List<Record> records) {
            expect(records.length, 3);
            expect(records[0], record1);
            expect(records[1], record2);
            expect(records[2], record3);
          });
        });
      });
    });

    group('find_null', () {
      test('first_last', () async {
        db = await setupForTest(ctx);
        store = db.mainStore;
        record1 = new Record(store, {"text": null}, 1);
        record2 = new Record(store, {"text": "hi"}, 2);
        await db.putRecords([record1, record2]);

        Finder finder = new Finder();
        finder.sortOrders = [new SortOrder("text", true)];
        List<Record> records = await store.findRecords(finder);
        expect(records, [record1, record2]);

        finder = new Finder();
        finder.sortOrders = [new SortOrder("text", true, true)];
        records = await store.findRecords(finder);
        expect(records, [record2, record1]);
      });
    });
  });
}
