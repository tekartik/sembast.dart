library sembast.transaction_deprecated_test;

// basically same as the io runner but with extra output
import 'package:sembast/sembast.dart';
import 'dart:async';
import 'package:sembast/src/database.dart';
import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('transaction_deprecated', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx);
    });

    tearDown(() {
      db.close();
    });

    test('put/clear/get in transaction', () async {
      // ignore: deprecated_member_use
      await db.inTransaction(() {
        return db.put("hi", 1).then((_) {
          return db.mainStore.clear().then((_) {
            return db.get(1).then((value) {
              expect(value, null);
            });
          });
        });
      });
    });

    test('put in transaction', () {
      List<Future> futures = [];
      // ignore: deprecated_member_use
      futures.add(db.inTransaction(() {
        return db.put("hi", 1).then((_) {
          return db.get(1).then((value) {
            expect(value, "hi");
          });
        });
      }));

      // here we are in a transaction so it will wait for the other to finish
      // ignore: deprecated_member_use
      futures.add(db.inTransaction(() {
        return db.get(1).then((value) {
          expect(value, "hi");
        });
      }));

      // here the value should not be loaded yet
      futures.add(db.get(1).then((value) {
        expect(value, null);
      }));
      return Future.wait(futures);
    });

    test('put in sub transaction', () {
      // ignore: deprecated_member_use
      return db.inTransaction(() {
        // ignore: deprecated_member_use
        return db.inTransaction(() {
          return db.put("hi", 1).then((_) {
            return db.get(1).then((value) {
              expect(value, "hi");
            });
          });
        });
      });
    });

    test('put in sub sub transaction', () {
      // ignore: deprecated_member_use
      return db.inTransaction(() {
        // ignore: deprecated_member_use
        return db.inTransaction(() {
          // ignore: deprecated_member_use
          return db.inTransaction(() {
            return db.put("hi", 1).then((_) {
              return db.get(1).then((value) {
                expect(value, "hi");
              });
            });
          });
        });
      });
    });

    test('put and throw', () {
      // ignore: deprecated_member_use
      return db.inTransaction(() {
        return db.put("hi", 1).then((_) {
          // still here
          return db.get(1).then((value) {
            expect(value, "hi");
          }).then((_) {
            throw "some failure";
          });
        });
      }).catchError((err) {
        expect(err, "some failure");
      }).then((_) {
        // put something else to make sure the txn has been cleaned
        return db.put("ho", 2).then((_) {
          return db.get(1).then((value) {
            expect(value, null);
          });
        });
      });
    });

    // timing is changing for dart2...
    test('transaction timing', () async {
      //sembastUseSynchronized = false;

      _do() async {
        StringBuffer sb = new StringBuffer();
        new Future(() {
          sb.write('1');
        });

        // ignore: deprecated_member_use
        await db.inTransaction(() async {
          // first action is delayed
          sb.write('2');

          var future = new Future(() {
            sb.write('4');
          });
          // not the second one
          // ignore: deprecated_member_use
          await db.inTransaction(() async {
            sb.write('3');
          });
          await future;
        });

        //print(sb);
        expect(sb.toString(), "1234");
      }

      //sembastUseSynchronized = false;
      //await _do();
      //sembastUseSynchronized = true;
      await _do();
    }, skip: true);
  });

  group('find_deprecated', () {
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

    test('in_transaction', () {
      // ignore: deprecated_member_use
      return db.inTransaction(() {
        Finder finder = new Finder();
        finder.filter = new Filter.equal(Field.value, "hi");
        return store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 1);
          expect(records[0], record1);
        }).then((_) {
          Record record = new Record(store, "he", 4);

          return db.putRecord(record).then((_) {
            finder.filter = new Filter.equal(Field.value, "he");
            return store.findRecords(finder).then((List<Record> records) {
              expect(records.length, 1);
              expect(records[0], record);
            });
          });
        }).then((_) {
          // delete ho
          return store.delete(2).then((_) {
            finder.filter = new Filter.equal(Field.value, "ho");
            return store.findRecords(finder).then((List<Record> records) {
              expect(records.length, 0);
            });
          });
        });
      });
    });

    test('in_transaction no_filter', () {
      // ignore: deprecated_member_use
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
      // ignore: deprecated_member_use
      return db.inTransaction(() {
        Finder finder = new Finder();

        // delete ho
        return store.delete(2).then((_) {
          finder.filter = new Filter.equal(Field.value, "ho");
          return store.findRecords(finder).then((List<Record> records) {
            expect(records.length, 0);
          });
        });
      });
    });
  });
}
